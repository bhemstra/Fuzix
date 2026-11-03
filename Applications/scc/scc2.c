/*
 *	scc2: turn the intermediate code from scc into a Fuzix (Bintools)
 *	relocatable object file.
 *
 *	scc2 file.o	reads file.o~1 (code), file.o~2 (data) and file.o~3
 *			(literals), writes file.o and removes the others.
 *
 *	Object layout, as the Fuzix assembler writes it: header, absolute
 *	stream, code stream, data stream, the empty streams of the other
 *	segments, symbol table. Each stream is the segment contents with
 *	relocations escaped by 0xDA and ends with DA 10.
 */

#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include "scc2.h"

#define REL_ESC		0xDA
#define REL_EOF		0x10
#define OSEG		14
#define NAMELEN		16

static int infd, outfd;
static u8 ibuf[256];
static u16 ipos, ilen;
static u8 obuf[256];
static u16 on;
static char *tmpname;

/* Function symbols and where they start */
struct func {
	u16 sym;
	u16 pos;
};
static struct func funcs[200];
static u8 nfuncs;

void fatal(const char *m)
{
	write(2, "scc2: ", 6);
	write(2, m, strlen(m));
	write(2, "\n", 1);
	exit(1);
}

static u8 rb(void)
{
	if (ipos == ilen) {
		int r = read(infd, ibuf, sizeof(ibuf));
		if (r <= 0)
			fatal("unexpected end of input");
		ilen = r;
		ipos = 0;
	}
	return ibuf[ipos++];
}

static u16 rw(void)
{
	u16 v = rb();
	return v | (rb() << 8);
}

static void oflush(void)
{
	if (on && write(outfd, obuf, on) != on)
		fatal("write error");
	on = 0;
}

static void ob(u8 c)
{
	if (on == sizeof(obuf))
		oflush();
	obuf[on++] = c;
}

static void oword(u16 v)
{
	ob(v);
	ob(v >> 8);
}

static void olong(uint32_t v)
{
	oword(v);
	oword(v >> 16);
}

static void oeof(void)
{
	ob(REL_ESC);
	ob(REL_EOF);
}

static uint32_t opos(void)
{
	return lseek(outfd, 0L, SEEK_CUR) + on;
}

void codeout(u8 *buf, u16 len)
{
	while (len--)
		ob(*buf++);
}

/* Append a temporary stream file */
static void append(char n)
{
	int fd, r;
	tmpname[strlen(tmpname) - 1] = n;
	fd = open(tmpname, O_RDONLY);
	if (fd == -1)
		fatal("missing temporary file");
	oflush();
	while ((r = read(fd, obuf, sizeof(obuf))) > 0)
		if (write(outfd, obuf, r) != r)
			fatal("write error");
	close(fd);
	unlink(tmpname);
	oeof();
}

static uint32_t segbase[OSEG];
static uint32_t symbase;

/* End of the code: write the other segments, symbols follow */
static void endcode(void)
{
	u8 i;
	oeof();
	segbase[2] = opos();
	append('2');
	for (i = 4; i < OSEG; i++) {
		segbase[i] = opos();
		if (i == SEG_LIT)
			append('3');
		else
			oeof();
	}
	symbase = opos();
}

static void opd(struct opd *o)
{
	o->k = rb();
	o->cls = rb();
	o->v = rw();
	o->sym = rw();
}

int main(int argc, char *argv[])
{
	struct opd o;
	uint32_t dbgbase;
	u16 sizes[OSEG];
	u8 op, a, b, i, n;
	u16 w;

	if (argc != 2)
		fatal("usage: scc2 file.o");
	tmpname = malloc(strlen(argv[1]) + 3);
	strcpy(tmpname, argv[1]);
	strcat(tmpname, "~1");
	infd = open(tmpname, O_RDONLY);
	if (infd == -1)
		fatal("cannot open input");
	outfd = open(argv[1], O_WRONLY | O_CREAT | O_TRUNC, 0644);
	if (outfd == -1)
		fatal("cannot create output");
	memset(segbase, 0, sizeof(segbase));
	memset(sizes, 0, sizeof(sizes));
	for (i = 0; i < 100; i++)
		ob(0);
	segbase[0] = 100;
	oeof();
	segbase[1] = 102;

	for (;;) {
		op = rb();
		switch (op) {
		case I_TOHL:
			opd(&o);
			tohl(&o);
			break;
		case I_TODE:
			opd(&o);
			tode(&o);
			break;
		case I_STORE:
			opd(&o);
			store(&o, rb());
			break;
		case I_FAR:
			far(rw());
			break;
		case I_SCALE:
			scale(rw());
			break;
		case I_OP:
			a = rb();
			b = rb();
			emitop(a, b, rb());
			break;
		case I_CONST:
			a = rb();
			w = rw();
			constop(a, w, rb());
			break;
		case I_JP:
			a = rb();
			w = rw();
			gb(a);
			glab(w);
			break;
		case I_LABEL:
			setlabel(rw());
			break;
		case I_CALLS:
			gcallsym(rw());
			break;
		case I_ADDSP:
			gaddsp(rw());
			break;
		case I_EXT:
			ext(rb());
			break;
		case I_RAW:
			n = rb();
			while (n--)
				gb(rb());
			break;
		case I_FBEGIN:
			if (nfuncs == 200)
				fatal("too many functions");
			funcs[nfuncs].sym = rw();
			funcs[nfuncs++].pos = codepos;
			funcbegin();
			break;
		case I_FEND:
			funcend(rw());
			break;
		case I_WORD:
			gw(rw());
			break;
		case I_LABW:
			glab(rw());
			break;
		case I_SYM:
			if (!symbase) {
				endcode();
				w = 0;
			}
			a = rb();
			ob(a);
			o.v = rw();
			/* functions: the value is where the code went */
			if ((a & 0x0F) == SEG_CODE)
				for (i = 0; i < nfuncs; i++)
					if (funcs[i].sym == w)
						o.v = funcs[i].pos;
			n = rb();
			for (i = 0; i < NAMELEN; i++)
				ob(i < n ? rb() : 0);
			while (n-- > NAMELEN)
				rb();
			oword(o.v);
			w++;
			break;
		case I_END:
			sizes[SEG_BSS] = rw();
			sizes[SEG_DATA] = rw();
			sizes[SEG_LIT] = rw();
			sizes[SEG_CODE] = codepos;
			goto done;
		default:
			fatal("bad intermediate code");
		}
	}
done:
	if (!symbase)
		endcode();
	dbgbase = opos();
	oflush();
	close(infd);
	tmpname[strlen(tmpname) - 1] = '1';
	unlink(tmpname);
	lseek(outfd, 0L, SEEK_SET);
	oword(0x3D1A);			/* magic */
	ob(1);				/* 8080 family */
	ob(0);				/* little endian */
	oword(1);			/* Z80 */
	oword(0);
	for (i = 0; i < OSEG; i++)
		olong(segbase[i]);
	for (i = 0; i < OSEG; i++)
		oword(sizes[i]);
	olong(symbase);
	olong(dbgbase);
	oflush();
	close(outfd);
	return 0;
}
