/*
 *	sld - a small linker for Fuzix Z80 programs
 *
 *	sld -o out file.o ... lib.a ...
 *
 *	Links Fuzix (Bintools) object files and ar libraries into a
 *	relocatable Fuzix executable, the same result as ldz80 followed by
 *	reloc. It is written to run in a 32K process: the objects are read
 *	from disk again for each pass and only the symbols of the modules
 *	that are linked are kept in memory.
 *
 *	The segments are laid out code, literal, data, bss from address 0.
 *	The relocation list (the address of the high byte of each absolute
 *	address) is appended to the data, as crt0 expects.
 */

#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>

typedef unsigned char u8;
typedef unsigned short u16;

#define MAGIC_OBJ	0x3D1A
#define NAMELEN		16
#define S_ENTRYSIZE	(3 + NAMELEN)
#define S_UNKNOWN	0x80
#define S_PUBLIC	0x40
#define S_SEGMENT	0x0F
#define REL_ESC		0xDA
#define REL_EOF		0x10
#define REL_OVERFLOW	0x20
#define REL_HIGH	0x30

#define ABSOLUTE	0
#define CODE		1
#define DATA		2
#define BSS		3
#define LITERAL		7
#define UNDEF		0xFF

/* The four segments we handle, in output order */
static const u8 segs[4] = { CODE, LITERAL, DATA, BSS };
#define SEGIDX(s)	((s) == CODE ? 0 : (s) == LITERAL ? 1 : (s) == DATA ? 2 : 3)

static const char *outname = "a.out";
static char **files;
static u8 nfiles;
static u8 errs;

static void msg(const char *a, const char *b)
{
	write(2, "sld: ", 5);
	write(2, a, strlen(a));
	if (b) {
		write(2, " ", 1);
		write(2, b, strlen(b));
	}
	write(2, "\n", 1);
}

static void fatal(const char *a, const char *b)
{
	msg(a, b);
	unlink(outname);
	exit(1);
}

/*
 *	Buffered input with seeking
 */
static int ifd = -1;
static u8 ibuf[256];
static u16 ipos, ilen;
static long ibase;		/* file offset of ibuf[0] */
static long isize;
static u8 curfile = 0xFF;

static void iopen(u8 f)
{
	if (curfile == f)
		return;
	if (ifd != -1)
		close(ifd);
	ifd = open(files[f], O_RDONLY);
	if (ifd == -1)
		fatal("cannot open", files[f]);
	curfile = f;
	isize = lseek(ifd, 0L, SEEK_END);
	lseek(ifd, 0L, SEEK_SET);
	ilen = ipos = 0;
	ibase = 0;
}

static void iseek(long off)
{
	if (off >= ibase && off < ibase + ilen) {
		ipos = off - ibase;
		return;
	}
	lseek(ifd, off, SEEK_SET);
	ibase = off;
	ilen = ipos = 0;
}

static u8 ib(void)
{
	int r;
	if (ipos == ilen) {
		ibase += ilen;
		r = read(ifd, ibuf, sizeof(ibuf));
		if (r <= 0)
			fatal("unexpected end of", files[curfile]);
		ilen = r;
		ipos = 0;
	}
	return ibuf[ipos++];
}

static u16 iw(void)
{
	u16 v = ib();
	return v | (ib() << 8);
}

static long il(void)
{
	long v = iw();
	return v | ((long)iw() << 16);
}

static void iread(u8 *p, u16 n)
{
	while (n--)
		*p++ = ib();
}

/*
 *	Output
 */
static int ofd;
static u8 obuf[256];
static u16 on;
static u16 dot;			/* address being written */

static void oflush(void)
{
	if (on && write(ofd, obuf, on) != on)
		fatal("write error", NULL);
	on = 0;
}

static void ob(u8 c)
{
	if (on == sizeof(obuf))
		oflush();
	obuf[on++] = c;
	dot++;
}

/* Relocations go to a temporary file as the crt0 byte stream */
static int rfd;
static char *rname;
static u8 rbuf[128];
static u8 rn;
static u16 rlast;
static u16 nrel;

static void rput(u8 c)
{
	if (rn == sizeof(rbuf)) {
		if (write(rfd, rbuf, rn) != rn)
			fatal("write error", NULL);
		rn = 0;
	}
	rbuf[rn++] = c;
	nrel++;
}

static void reloc(u16 addr)
{
	while (addr - rlast > 254) {
		rput(255);
		rlast += 254;
	}
	rput(addr - rlast);
	rlast = addr;
}

/*
 *	Objects
 */
struct object {
	struct object *next;
	long off;		/* in the file (archive member) */
	u8 file;
	u16 size[4];		/* code literal data bss */
	u16 base[4];
	long segbase[4];
	long symbase;
	u16 nsym;
};

static struct object *objects, *lastobj;
static u16 total[4];

/*
 *	Global symbols
 */
struct symbol {
	struct symbol *next;
	char name[NAMELEN];
	u8 seg;			/* UNDEF if not defined (yet) */
	u16 value;
	struct object *obj;	/* defined by (NULL: absolute/internal) */
};

#define NHASH 64
static struct symbol *symtab[NHASH];
static u16 nundef;

static void *xalloc(u16 n)
{
	void *p = malloc(n);
	if (!p)
		fatal("out of memory", NULL);
	memset(p, 0, n);
	return p;
}

static u8 hash(const char *n)
{
	u8 h = 0, i;
	for (i = 0; i < NAMELEN && n[i]; i++)
		h = (h << 1) + n[i];
	return h & (NHASH - 1);
}

static struct symbol *findsym(const char *n)
{
	struct symbol *s;
	for (s = symtab[hash(n)]; s; s = s->next)
		if (memcmp(s->name, n, NAMELEN) == 0)
			return s;
	return NULL;
}

static struct symbol *addsym(const char *n)
{
	struct symbol *s = findsym(n);
	u8 h;
	if (s)
		return s;
	s = xalloc(sizeof(struct symbol));
	memcpy(s->name, n, NAMELEN);
	s->seg = UNDEF;
	h = hash(n);
	s->next = symtab[h];
	symtab[h] = s;
	nundef++;
	return s;
}

static char *pname(const char *n)
{
	static char b[NAMELEN + 1];
	memcpy(b, n, NAMELEN);
	b[NAMELEN] = 0;
	return b;
}

/* Read an object header at off. Returns 0 if it is not an object. */
static u8 readhdr(struct object *o)
{
	u8 i;
	long sb[14];
	u16 sz[14];
	iseek(o->off);
	if (iw() != MAGIC_OBJ)
		return 0;
	if (ib() != 1)
		fatal("not a Z80 object", files[o->file]);
	ib();
	iw();
	iw();
	for (i = 0; i < 14; i++)
		sb[i] = il();
	for (i = 0; i < 14; i++)
		sz[i] = iw();
	o->symbase = il();
	o->nsym = (il() - o->symbase) / S_ENTRYSIZE;
	if (sz[ABSOLUTE])
		fatal("absolute code in", files[o->file]);
	for (i = 0; i < 4; i++) {
		o->size[i] = sz[segs[i]];
		o->segbase[i] = sb[segs[i]];
	}
	for (i = 4; i < 14; i++)
		if (sz[i] && i != LITERAL)
			fatal("unsupported segment in", files[o->file]);
	return 1;
}

/* One symbol table entry */
static u8 sflags;
static char sname[NAMELEN];
static u16 svalue;

static void readsym(void)
{
	sflags = ib();
	iread((u8 *)sname, NAMELEN);
	svalue = iw();
}

/* Does this object define a symbol we need */
static u8 wanted(struct object *o)
{
	u16 i;
	struct symbol *s;
	if (!nundef)
		return 0;
	iseek(o->off + o->symbase);
	for (i = 0; i < o->nsym; i++) {
		readsym();
		if ((sflags & (S_UNKNOWN | S_PUBLIC)) == S_PUBLIC) {
			s = findsym(sname);
			if (s && s->seg == UNDEF)
				return 1;
		}
	}
	return 0;
}

/* Link in an object: enter its symbols */
static void load(struct object *o)
{
	u16 i;
	struct symbol *s;
	struct object *n = xalloc(sizeof(struct object));
	memcpy(n, o, sizeof(struct object));
	n->next = NULL;
	if (lastobj)
		lastobj->next = n;
	else
		objects = n;
	lastobj = n;
	iseek(o->off + o->symbase);
	for (i = 0; i < o->nsym; i++) {
		readsym();
		if (sflags & S_UNKNOWN)
			addsym(sname);
		else if (sflags & S_PUBLIC) {
			s = addsym(sname);
			if (s->seg != UNDEF) {
				msg("multiply defined:", pname(sname));
				errs = 1;
				continue;
			}
			s->seg = sflags & S_SEGMENT;
			s->value = svalue;
			s->obj = n;
			nundef--;
		}
	}
}

static u8 loaded(u8 f, long off)
{
	struct object *o;
	for (o = objects; o; o = o->next)
		if (o->file == f && o->off == off)
			return 1;
	return 0;
}

static long decimal(const char *p, u8 n)
{
	long v = 0;
	while (n-- && *p >= '0' && *p <= '9')
		v = v * 10 + *p++ - '0';
	return v;
}

/* Offer the members of a library until nothing more is needed */
static void library(u8 f)
{
	struct object o;
	char hdr[60];
	long pos, size;
	u8 more;

	do {
		more = 0;
		pos = 8;
		while (pos + 60 <= isize) {
			iseek(pos);
			iread((u8 *)hdr, 60);
			size = decimal(hdr + 48, 10);
			memset(&o, 0, sizeof(o));
			o.file = f;
			o.off = pos + 60;
			if (!loaded(f, o.off) && readhdr(&o) && wanted(&o)) {
				load(&o);
				more = 1;
			}
			pos += 60 + size + (size & 1);
		}
	} while (more && nundef);
}

static void addfile(u8 f)
{
	struct object o;
	char mag[8];
	iopen(f);
	iseek(0);
	iread((u8 *)mag, 8);
	if (memcmp(mag, "!<arch>\n", 8) == 0) {
		library(f);
		return;
	}
	memset(&o, 0, sizeof(o));
	o.file = f;
	if (!readhdr(&o))
		fatal("not an object file:", files[f]);
	load(&o);
}

static void internal(const char *n, u8 seg, u16 v)
{
	char b[NAMELEN];
	struct symbol *s;
	memset(b, 0, NAMELEN);
	strncpy(b, n, NAMELEN);
	s = findsym(b);
	if (!s)
		return;
	if (s->seg == UNDEF)
		nundef--;
	s->seg = seg;
	s->value = v;
	s->obj = NULL;
}

/* Work out where everything goes */
static void layout(void)
{
	struct object *o;
	struct symbol *s;
	u16 pos[4], start;
	u8 i;

	for (o = objects; o; o = o->next)
		for (i = 0; i < 4; i++)
			total[i] += o->size[i];
	start = 0;
	for (i = 0; i < 4; i++) {
		pos[i] = start;
		start += total[i];
		if (start < pos[i])
			fatal("program too large", NULL);
	}
	for (o = objects; o; o = o->next)
		for (i = 0; i < 4; i++) {
			o->base[i] = pos[i];
			pos[i] += o->size[i];
		}
	for (i = 0; i < NHASH; i++)
		for (s = symtab[i]; s; s = s->next)
			if (s->obj && s->seg != ABSOLUTE)
				s->value += s->obj->base[SEGIDX(s->seg)];
	/* The linker symbols crt0 uses: addresses are relocatable */
	internal("__code", CODE, 0);
	internal("__literal", CODE, total[0]);
	internal("__data", DATA, total[0] + total[1]);
	internal("__bss", BSS, total[0] + total[1] + total[2]);
	internal("__end", BSS, start);
	internal("__code_size", ABSOLUTE, total[0]);
	internal("__literal_size", ABSOLUTE, total[1]);
	internal("__data_size", ABSOLUTE, total[2]);
	internal("__bss_size", ABSOLUTE, total[3]);
}

/*
 *	Write out one segment of one object, relocating it
 */
struct map {
	u8 seg;
	u16 value;
};

static void relocate(struct object *o, u8 si, struct map *m)
{
	u8 c, high, size, seg;
	u16 v;
	struct map *t;

	iseek(o->off + o->segbase[si]);
	for (;;) {
		c = ib();
		if (c != REL_ESC) {
			ob(c);
			continue;
		}
		c = ib();
		if (c == REL_EOF)
			return;
		if (c == 0) {
			ob(REL_ESC);
			continue;
		}
		high = 0;
		if (c == REL_OVERFLOW)
			c = ib();
		if (c == REL_HIGH) {
			high = 1;
			c = ib();
		}
		size = ((c >> 4) & 3) + 1;
		if (c & 0x80) {
			seg = c & S_SEGMENT;
			v = size == 2 ? iw() : ib();
			if (seg == ABSOLUTE || (seg != CODE && seg != DATA && seg != BSS && seg != LITERAL))
				fatal("bad relocation in", files[o->file]);
			v += o->base[SEGIDX(seg)];
		} else if ((c & 0x0F) == 1) {
			t = m + iw();
			v = size == 2 ? iw() : ib();
			if (t->seg == UNDEF) {
				errs = 1;
				v = 0;
				seg = ABSOLUTE;
			} else {
				seg = t->seg;
				v += t->value;
			}
		} else
			fatal("unsupported relocation in", files[o->file]);
		if (high) {
			if (seg != ABSOLUTE)
				reloc(dot);
			ob(v >> 8);
		} else if (size == 2) {
			if (seg != ABSOLUTE)
				reloc(dot + 1);
			ob(v);
			ob(v >> 8);
		} else
			ob(v);
	}
}

static void writeseg(u8 si)
{
	struct object *o;
	struct map *m;
	struct symbol *s;
	u16 i;
	u8 seg;

	for (o = objects; o; o = o->next) {
		if (!o->size[si])
			continue;
		iopen(o->file);
		/* Map the object symbols to their final values */
		m = xalloc(o->nsym * sizeof(struct map) + 1);
		iseek(o->off + o->symbase);
		for (i = 0; i < o->nsym; i++) {
			readsym();
			seg = sflags & S_SEGMENT;
			if (!(sflags & S_UNKNOWN)) {
				m[i].seg = seg;
				m[i].value = svalue;
				if (seg != ABSOLUTE)
					m[i].value += o->base[SEGIDX(seg)];
			} else {
				s = findsym(sname);
				m[i].seg = s ? s->seg : UNDEF;
				m[i].value = s ? s->value : 0;
			}
		}
		dot = o->base[si];
		relocate(o, si, m);
		free(m);
	}
}

int main(int argc, char *argv[])
{
	int i;
	struct symbol *s;
	u8 hdr[16];
	u16 data, bss;

	files = argv;
	for (i = 1; i < argc; i++) {
		if (strcmp(argv[i], "-o") == 0 && i + 1 < argc) {
			outname = argv[++i];
			argv[i] = NULL;
			argv[i - 1] = NULL;
		}
	}
	nfiles = argc;
	for (i = 1; i < argc; i++)
		if (argv[i])
			addfile(i);
	if (errs)
		fatal("errors", NULL);
	layout();
	for (i = 0; i < NHASH; i++)
		for (s = symtab[i]; s; s = s->next)
			if (s->seg == UNDEF) {
				msg("undefined:", pname(s->name));
				errs = 1;
			}
	if (errs)
		fatal("link failed", NULL);

	ofd = open(outname, O_RDWR | O_CREAT | O_TRUNC, 0755);
	if (ofd == -1)
		fatal("cannot create", outname);
	rname = malloc(strlen(outname) + 3);
	strcpy(rname, outname);
	strcat(rname, "~r");
	rfd = open(rname, O_RDWR | O_CREAT | O_TRUNC, 0600);
	if (rfd == -1)
		fatal("cannot create", rname);
	writeseg(0);
	writeseg(1);
	writeseg(2);
	oflush();
	/* Append the relocations to the data */
	rput(0);
	write(rfd, rbuf, rn);
	lseek(rfd, 0L, SEEK_SET);
	while ((i = read(rfd, obuf, sizeof(obuf))) > 0)
		write(ofd, obuf, i);
	close(rfd);
	unlink(rname);
	/* Fix up the header the way reloc does */
	lseek(ofd, 0L, SEEK_SET);
	if (read(ofd, hdr, 16) != 16 || hdr[0] != 0xA8 || hdr[1] != 0x80)
		fatal("crt0 must come first", NULL);
	data = hdr[8] | (hdr[9] << 8);
	bss = hdr[10] | (hdr[11] << 8);
	data += nrel;
	bss = nrel <= bss ? bss - nrel : 0;
	hdr[8] = data;
	hdr[9] = data >> 8;
	hdr[10] = bss;
	hdr[11] = bss >> 8;
	lseek(ofd, 0L, SEEK_SET);
	write(ofd, hdr, 16);
	close(ofd);
	return 0;
}
