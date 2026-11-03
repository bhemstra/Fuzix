/*
 *	scc: write the intermediate stream and the data segments
 *
 *	For an output file X the front end writes X~1 (intermediate code
 *	and symbols), X~2 (data segment stream) and X~3 (literal segment
 *	stream). scc2 turns them into X.
 */

#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include "scc.h"
#include "ir.h"

#define REL_ESC		0xDA

struct wbuf {
	int fd;
	u8 n;
	u8 b[128];
};

static struct wbuf ib, db, lb;
static u8 raw[16];
static u8 nraw;

u16 datapos, bsspos, litpos;
u8 nocode;
static u16 nlab;

static void wflush(struct wbuf *w)
{
	if (w->n && write(w->fd, w->b, w->n) != w->n)
		fatal("write error");
	w->n = 0;
}

static void wput(struct wbuf *w, u8 c)
{
	if (w->n == sizeof(w->b))
		wflush(w);
	w->b[w->n++] = c;
}

static void wword(struct wbuf *w, u16 v)
{
	wput(w, v);
	wput(w, v >> 8);
}

static int tmpfile(const char *name, char n)
{
	char *p = alloc(strlen(name) + 3);
	int fd;
	strcpy(p, name);
	strcat(p, "~1");
	p[strlen(p) - 1] = n;
	fd = open(p, O_WRONLY | O_CREAT | O_TRUNC, 0600);
	if (fd == -1)
		fatal("cannot create temporary file");
	return fd;
}

void outinit(const char *name)
{
	ib.fd = tmpfile(name, '1');
	db.fd = tmpfile(name, '2');
	lb.fd = tmpfile(name, '3');
}

/*
 *	Intermediate code
 */
static void flushraw(void)
{
	u8 i;
	if (nraw) {
		wput(&ib, I_RAW);
		wput(&ib, nraw);
		for (i = 0; i < nraw; i++)
			wput(&ib, raw[i]);
		nraw = 0;
	}
}

/* Start an intermediate record */
void irop(u8 op)
{
	flushraw();
	wput(&ib, op);
}

void irb(u8 b)
{
	wput(&ib, b);
}

void irw(u16 w)
{
	wword(&ib, w);
}

void iropd(u8 op, struct opd *o, u8 cls)
{
	if (nocode)
		return;
	irop(op);
	irb(o->k);
	irb(cls);
	irw(o->v);
	irw(o->sym);
}

void gb(u8 b)
{
	if (nocode)
		return;
	if (nraw == sizeof(raw))
		flushraw();
	raw[nraw++] = b;
}

void g2(u8 a, u8 b)
{
	gb(a);
	gb(b);
}

void g3(u8 a, u8 b, u8 c)
{
	gb(a);
	gb(b);
	gb(c);
}

void gw(u16 w)
{
	gb(w);
	gb(w >> 8);
}

void gld_hl(u16 v)
{
	gb(0x21);
	gw(v);
}

void gld_de(u16 v)
{
	gb(0x11);
	gw(v);
}

void gix(u8 op, s16 off)
{
	g3(0xDD, op, off);
}

/* Records with one word operand */
static void irop1(u8 op, u16 w)
{
	if (nocode)
		return;
	irop(op);
	irw(w);
}

void gjp(u8 op, u16 l)
{
	if (nocode)
		return;
	irop(I_JP);
	irb(op);
	irw(l);
}

u16 newlabel(void)
{
	if (nlab == 256)
		fatal("function too complex");
	return nlab++;
}

void setlabel(u16 l)
{
	irop1(I_LABEL, l);
}

void glabword(u16 l)
{
	irop1(I_LABW, l);
}

/* The run time helpers are object symbols 0-10 (see ir.h) */
void gcall(u8 h)
{
	irop1(I_CALLS, h);
}

static const char *hnames[] = {
	"__sccmul", "__sccdiv", "__sccudiv", "__sccmod", "__sccumod",
	"__sccshl", "__sccshr", "__sccushr", "__sccjphl", "__sccswitch",
	"__sccrev"
};

void helpers(void)
{
	u8 i;
	for (i = 0; i < sizeof(hnames) / sizeof(hnames[0]); i++)
		newsym(NULL, hnames[i]);
}

void gcallsym(u16 sym)
{
	irop1(I_CALLS, sym);
}

void gaddsp(s16 n)
{
	irop1(I_ADDSP, n);
}

void gscale(u16 n)
{
	irop1(I_SCALE, n);
}

void gfar(s16 off)
{
	irop1(I_FAR, off);
}

void funcbegin(u16 sym)
{
	nlab = 0;
	irop1(I_FBEGIN, sym);
}

void funcend(u16 frame)
{
	irop1(I_FEND, frame);
}

/*
 *	Data and literal segments
 */
static void dput(struct wbuf *w, u8 b)
{
	wput(w, b);
	if (b == REL_ESC)
		wput(w, 0);
}

void dbyte(u8 b)
{
	dput(&db, b);
	datapos++;
}

void dword(u16 w)
{
	dbyte(w);
	dbyte(w >> 8);
}

void drel(u8 seg, u16 off)
{
	wput(&db, REL_ESC);
	wput(&db, 0x90 | seg);
	wword(&db, off);
	datapos += 2;
}

void dsym(u16 sym, u16 off)
{
	wput(&db, REL_ESC);
	wput(&db, 0x11);
	wword(&db, sym);
	wword(&db, off);
	datapos += 2;
}

void lbyte(u8 b)
{
	dput(&lb, b);
	litpos++;
}

/*
 *	Object symbols
 */
struct osym {
	const char *s;
	u8 flags;
	u16 val;
};

#define SYMCHUNK 32
static struct osym *osyms[16];
static u16 nosyms;

static struct osym *osym(u16 n)
{
	return osyms[n / SYMCHUNK] + n % SYMCHUNK;
}

u16 newsym(struct name *n, const char *s)
{
	struct osym *o;
	if (nosyms % SYMCHUNK == 0) {
		if (nosyms == 16 * SYMCHUNK)
			fatal("too many symbols");
		osyms[nosyms / SYMCHUNK] = alloc(SYMCHUNK * sizeof(struct osym));
	}
	o = osym(nosyms);
	o->s = s;
	o->flags = 0x80 | 0x0F;		/* undefined */
	if (n) {
		n->val = nosyms;
		n->flags |= F_HASSYM;
	}
	return nosyms++;
}

void defsym(u16 sym, u8 seg, u16 off, u8 pub)
{
	struct osym *o = osym(sym);
	o->flags = seg | (pub ? 0x40 : 0);
	o->val = off;
}

void outfinish(void)
{
	u16 i;
	struct osym *o;
	flushraw();
	for (i = 0; i < nosyms; i++) {
		o = osym(i);
		irop(I_SYM);
		irb(o->flags);
		irw(o->val);
		irb(strlen(o->s));
		while (*o->s)
			irb(*o->s++);
	}
	irop(I_END);
	irw(bsspos);
	irw(datapos);
	irw(litpos);
	wflush(&ib);
	wflush(&db);
	wflush(&lb);
	close(ib.fd);
	close(db.fd);
	close(lb.fd);
}
