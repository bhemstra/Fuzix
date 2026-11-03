/*
 *	scc2: Z80 code generation
 *
 *	The code of the function being compiled is kept in memory as an
 *	object stream (0xDA escaped) so that forward jumps can be patched
 *	when the label is reached. Each forward reference holds the buffer
 *	index of the previous reference to the same label until then.
 */

#include <string.h>
#include "scc2.h"

#define CBUF	6144
#define NLAB	256
#define NOVAL	0xFFFF

static u8 cbuf[CBUF];
static u16 cn;
static u16 labval[NLAB];
static u16 labchain[NLAB];
static u16 framepatch;
u16 codepos;

static void room(u8 n)
{
	if (cn + n > CBUF)
		fatal("function too large");
}

void gb(u8 b)
{
	room(2);
	cbuf[cn++] = b;
	if (b == 0xDA)
		cbuf[cn++] = 0;
	codepos++;
}

static void g2(u8 a, u8 b)
{
	gb(a);
	gb(b);
}

static void g3(u8 a, u8 b, u8 c)
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

static void gld_hl(u16 v)
{
	gb(0x21);
	gw(v);
}

static void gld_de(u16 v)
{
	gb(0x11);
	gw(v);
}

static void gix(u8 op, s16 off)
{
	g3(0xDD, op, off);
}

static void raw(u8 b)
{
	cbuf[cn++] = b;
}

/* 16 bit address relative to one of our segments */
static void grel(u8 seg, u16 off)
{
	room(4);
	raw(0xDA);
	raw(0x90 | seg);
	raw(off);
	raw(off >> 8);
	codepos += 2;
}

/* 16 bit address of an object symbol plus offset */
static void gsym(u16 sym, u16 off)
{
	room(6);
	raw(0xDA);
	raw(0x11);
	raw(sym);
	raw(sym >> 8);
	raw(off);
	raw(off >> 8);
	codepos += 2;
}

/* A word holding the address of a label */
void glab(u16 l)
{
	if (labval[l] != NOVAL) {
		grel(SEG_CODE, labval[l]);
		return;
	}
	room(4);
	raw(0xDA);
	raw(0x91);
	raw(labchain[l]);
	raw(labchain[l] >> 8);
	labchain[l] = cn - 2;
	codepos += 2;
}

void setlabel(u16 l)
{
	u16 i, n;
	labval[l] = codepos;
	i = labchain[l];
	while (i != NOVAL) {
		n = cbuf[i] | (cbuf[i + 1] << 8);
		cbuf[i] = codepos;
		cbuf[i + 1] = codepos >> 8;
		i = n;
	}
	labchain[l] = NOVAL;
}

void gcallsym(u16 sym)
{
	gb(0xCD);
	gsym(sym, 0);
}

void gaddsp(s16 n)
{
	if (n <= 8) {
		while (n > 0) {
			gb(0xD1);	/* pop de */
			n -= 2;
		}
		return;
	}
	gb(0xEB);
	gld_hl(n);
	g2(0x39, 0xF9);		/* add hl,sp; ld sp,hl */
	gb(0xEB);
}

void funcbegin(void)
{
	cn = 0;
	memset(labval, 0xFF, sizeof(labval));
	memset(labchain, 0xFF, sizeof(labchain));
	g2(0xDD, 0xE5);		/* push ix */
	g2(0xDD, 0x21);		/* ld ix,0 */
	gw(0);
	g2(0xDD, 0x39);		/* add ix,sp */
	gb(0x21);		/* ld hl,-frame */
	framepatch = cn;
	gw(0);
	g2(0x39, 0xF9);		/* add hl,sp; ld sp,hl */
}

void funcend(u16 frame)
{
	u16 i;
	if (((-frame) & 0xFF) == 0xDA)
		frame++;
	frame = -frame;
	if ((frame >> 8) == 0xDA)
		fatal("too many locals");
	cbuf[framepatch] = frame;
	cbuf[framepatch + 1] = frame >> 8;
	g2(0xDD, 0xF9);		/* ld sp,ix */
	g2(0xDD, 0xE1);		/* pop ix */
	gb(0xC9);		/* ret */
	for (i = 0; i < NLAB; i++)
		if (labchain[i] != NOVAL)
			fatal("undefined label");
	codeout(cbuf, cn);
}

/*
 *	Operands
 */
static void addrop(struct opd *o)
{
	if (o->k == O_GVAR || o->k == O_GADR)
		gsym(o->sym, o->v);
	else
		grel(o->sym, o->v);
}

/* Extend the char in L */
void ext(u8 cls)
{
	if (cls == OC_SCHAR) {
		g2(0x7D, 0x17);		/* ld a,l; rla */
		g2(0x9F, 0x67);		/* sbc a,a; ld h,a */
	} else
		g2(0x26, 0x00);		/* ld h,0 */
}

/* HL = IX + off */
void far(s16 off)
{
	g3(0xDD, 0xE5, 0xE1);	/* push ix; pop hl */
	if (off) {
		gld_de(off);
		gb(0x19);	/* add hl,de */
	}
}

void tohl(struct opd *o)
{
	u8 c = o->cls != OC_WORD;
	switch (o->k) {
	case O_CON:
		gld_hl(o->v);
		break;
	case O_GADR:
	case O_SADR:
		gb(0x21);
		addrop(o);
		break;
	case O_LADR:
		far(o->v);
		break;
	case O_GVAR:
	case O_SVAR:
		if (c) {
			gb(0x3A);	/* ld a,(nn) */
			addrop(o);
			gb(0x6F);	/* ld l,a */
			ext(o->cls);
		} else {
			gb(0x2A);	/* ld hl,(nn) */
			addrop(o);
		}
		break;
	case O_LVAR:
		gix(0x6E, o->v);	/* ld l,(ix+d) */
		if (c)
			ext(o->cls);
		else
			gix(0x66, o->v + 1);
		break;
	case O_IND:
		if (c) {
			gb(0x6E);	/* ld l,(hl) */
			ext(o->cls);
		} else {
			g2(0x7E, 0x23);	/* ld a,(hl); inc hl */
			g2(0x66, 0x6F);	/* ld h,(hl); ld l,a */
		}
		break;
	case O_CMP:
		gld_hl(0);
		/* jr not-cond,+1 */
		gb(o->v == JP_Z ? 0x20 : o->v == JP_NZ ? 0x28 :
			o->v == JP_C ? 0x30 : 0x38);
		gb(1);
		gb(0x23);		/* inc hl */
		break;
	}
}

/* Load a simple operand into DE */
void tode(struct opd *o)
{
	switch (o->k) {
	case O_CON:
		gld_de(o->v);
		return;
	case O_GADR:
	case O_SADR:
		gb(0x11);
		addrop(o);
		return;
	case O_LADR:
		gb(0xE5);		/* push hl */
		far(o->v);
		gb(0xEB);		/* ex de,hl */
		gb(0xE1);		/* pop hl */
		return;
	case O_GVAR:
	case O_SVAR:
		if (o->cls != OC_WORD) {
			gb(0x3A);
			addrop(o);
			gb(0x5F);	/* ld e,a */
		} else {
			g2(0xED, 0x5B);	/* ld de,(nn) */
			addrop(o);
			return;
		}
		break;
	case O_LVAR:
		gix(0x5E, o->v);	/* ld e,(ix+d) */
		if (o->cls == OC_WORD) {
			gix(0x56, o->v + 1);
			return;
		}
		gb(0x7B);		/* ld a,e */
		break;
	}
	/* char in A and E: extend into D */
	if (o->cls == OC_SCHAR)
		g3(0x17, 0x9F, 0x57);	/* rla; sbc a,a; ld d,a */
	else
		g2(0x16, 0x00);		/* ld d,0 */
}

/* Store HL. For O_IND the address is in DE. */
void store(struct opd *o, u8 fixh)
{
	u8 c = o->cls != OC_WORD;
	switch (o->k) {
	case O_GVAR:
	case O_SVAR:
		if (c) {
			gb(0x7D);
			gb(0x32);	/* ld (nn),a */
		} else
			gb(0x22);	/* ld (nn),hl */
		addrop(o);
		break;
	case O_LVAR:
		gix(0x75, o->v);	/* ld (ix+d),l */
		if (!c)
			gix(0x74, o->v + 1);
		break;
	case O_IND:
		g2(0x7D, 0x12);		/* ld a,l; ld (de),a */
		if (!c)
			g3(0x13, 0x7C, 0x12);	/* inc de; ld a,h; ld (de),a */
		break;
	}
	if (c && fixh)
		ext(o->cls);
}

/* Multiply HL by a constant, keeping DE */
void scale(u16 n)
{
	if (n == 1)
		return;
	if (n == 2 || n == 4 || n == 8) {
		while (n > 1) {
			gb(0x29);	/* add hl,hl */
			n >>= 1;
		}
		return;
	}
	gb(0xD5);			/* push de */
	gld_de(n);
	gcallsym(helper(H_MUL));
	gb(0xD1);
}

/*
 *	Binary operators. Normally DE is the left operand and HL the right
 *	one; with swap set HL is the left one and DE the right.
 */
void emitop(u8 op, u8 uns, u8 swap)
{
	switch (op) {
	case '+':
		gb(0x19);
		return;
	case '-':
		if (!swap)
			gb(0xEB);
		g3(0xB7, 0xED, 0x52);	/* or a; sbc hl,de */
		return;
	case '*':
		gcallsym(helper(H_MUL));
		return;
	case '/':
	case '%':
	case T_SHL:
	case T_SHR:
		if (swap)
			gb(0xEB);
		if (op == '/')
			op = uns ? H_UDIV : H_DIV;
		else if (op == '%')
			op = uns ? H_UMOD : H_MOD;
		else if (op == T_SHL)
			op = H_SHL;
		else
			op = uns ? H_USHR : H_SHR;
		gcallsym(helper(op));
		return;
	case '&':
		g3(0x7D, 0xA3, 0x6F);
		g3(0x7C, 0xA2, 0x67);
		return;
	case '|':
		g3(0x7D, 0xB3, 0x6F);
		g3(0x7C, 0xB2, 0x67);
		return;
	case '^':
		g3(0x7D, 0xAB, 0x6F);
		g3(0x7C, 0xAA, 0x67);
		return;
	}
	/* Comparisons: the front end knows which flag holds the result */
	if (op != T_EQ && op != T_NE && !uns) {
		/* Signed: flip the sign bits and compare unsigned */
		g2(0x7C, 0xEE);
		g2(0x80, 0x67);
		g2(0x7A, 0xEE);
		g2(0x80, 0x57);
	}
	if (((op == '<' || op == T_GE) && !swap) || ((op == '>' || op == T_LE) && swap))
		gb(0xEB);
	g3(0xB7, 0xED, 0x52);
}

/* HL op= constant */
void constop(u8 op, u16 v, u8 uns)
{
	u8 lo = v, hi = v >> 8;
	switch (op) {
	case '-':
		v = -v;
	case '+':
		if (v == 1 || v == 2) {
			while (v--)
				gb(0x23);
		} else if (v == 0xFFFF || v == 0xFFFE) {
			while (v++)
				gb(0x2B);
		} else if (v) {
			gld_de(v);
			gb(0x19);
		}
		return;
	case '&':
	case '|':
	case '^':
		op = op == '&' ? 0xE6 : op == '|' ? 0xF6 : 0xEE;
		gb(0x7D);
		g2(op, lo);
		g2(0x6F, 0x7C);
		g2(op, hi);
		gb(0x67);
		return;
	case T_SHL:
		if (v < 8) {
			while (v--)
				gb(0x29);
			return;
		}
		break;
	case T_SHR:
		if (v < 8) {
			while (v--) {
				g2(0xCB, uns ? 0x3C : 0x2C);	/* srl/sra h */
				g2(0xCB, 0x1D);			/* rr l */
			}
			return;
		}
		break;
	case '*':
		if (v == 1 || v == 2 || v == 4 || v == 8) {
			scale(v);
			return;
		}
		break;
	}
	gld_de(v);
	emitop(op, uns, 1);
}
