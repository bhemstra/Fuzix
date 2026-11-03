/*
 *	scc: expressions
 *
 *	Values are computed in HL. For a binary operator the left operand
 *	ends up in DE and the right in HL. Simple operands (constants,
 *	variables) are not loaded until needed, which saves most of the
 *	pushes and pops.
 */

#include <string.h>
#include "scc.h"


static void unary(struct opd *o);
static void binexpr(struct opd *o, u8 minprec);

static void notlong(u8 t)
{
	if (t >= TY_LONG && t <= TY_FLOAT)
		error("long and float are not supported");
}


static u8 farlocal(struct opd *o)
{
	return o->k == O_LVAR && (o->v < -128 || o->v > 126);
}

/* Turn a far local into an indirect operand (address in HL) */
static void farfix(struct opd *o)
{
	if (farlocal(o)) {
		gfar(o->v);
		o->k = O_IND;
	}
}
static u8 isagg(u8 t)
{
	u8 k = types[t].kind;
	return k == TK_ARRAY || k == TK_FUNC;
}

/* Can this operand be loaded into DE without touching HL */
static u8 simple(struct opd *o)
{
	switch (o->k) {
	case O_CON: case O_GADR: case O_SADR: case O_GVAR: case O_SVAR:
		return 1;
	case O_LVAR:
		return !farlocal(o) && !isagg(o->type);
	}
	return 0;
}

static u8 cls(u8 t)
{
	if (t == TY_SCHAR)
		return OC_SCHAR;
	return t == TY_CHAR ? OC_UCHAR : OC_WORD;
}

/* Extend the char in L (unsigned) or sign extend it */
static void extl(u8 t)
{
	if (nocode)
		return;
	irop(I_EXT);
	irb(cls(t));
}
void tohl(struct opd *o)
{
	u8 t = o->type;
	u8 k = types[t].kind;

	if (o->k == O_REG)
		return;
	if (k == TK_STRUCT && o->k >= O_GVAR && o->k <= O_IND)
		error("struct values are not supported");
	if (o->k >= O_GVAR && o->k <= O_IND && isagg(t)) {
		/* arrays and functions stand for their address */
		if (o->k == O_IND)
			o->k = O_REG;
		else
			o->k -= O_GVAR - O_GADR;
		if (o->k != O_REG) {
			tohl(o);
			return;
		}
	}
	notlong(t);
	farfix(o);
	iropd(I_TOHL, o, cls(t));
	if (o->k == O_CMP)
		t = TY_INT;
	o->k = O_REG;
	o->type = decay(t);
}

void rvalue(struct opd *o)
{
	tohl(o);
}

/* Load a simple operand into DE */
static void tode(struct opd *o)
{
	u8 t = o->type;
	if (o->k >= O_GVAR && o->k <= O_LVAR && isagg(t))
		o->k -= O_GVAR - O_GADR;
	notlong(t);
	iropd(I_TODE, o, cls(t));
}
/*
 *	Store HL into an lvalue. For O_IND the address is in DE.
 *	fixh: leave a valid 16 bit value in HL after a char store
 */
static void store(struct opd *o, u8 fixh)
{
	u8 t = o->type;
	if (types[t].kind == TK_STRUCT || isagg(t))
		error("cannot assign to this");
	if (!(o->k >= O_GVAR && o->k <= O_IND && o->k != O_REG))
		error("lvalue required");
	notlong(t);
	iropd(I_STORE, o, cls(t));
	irb(fixh);
}

static u8 islvalue(struct opd *o)
{
	return o->k >= O_GVAR && o->k <= O_IND;
}

/* Multiply HL by a constant, keeping DE */
static void scalehl(u16 n)
{
	if (n != 1)
		gscale(n);
}
static u8 arith(u8 a, u8 b)
{
	if (a == TY_UINT || b == TY_UINT)
		return TY_UINT;
	return TY_INT;
}

static u8 unsignedop(struct opd *a, struct opd *b)
{
	return a->type == TY_UINT || b->type == TY_UINT || isptr(a->type) || isptr(b->type);
}

static u16 fold(u8 op, u16 a, u16 b, u8 uns)
{
	s16 x = a, y = b;
	switch (op) {
	case '+': return a + b;
	case '-': return a - b;
	case '*': return a * b;
	case '/': case '%':
		if (b == 0) {
			error("division by zero");
			return 0;
		}
		if (op == '/')
			return uns ? a / b : (u16)(x / y);
		return uns ? a % b : (u16)(x % y);
	case T_SHL: return a << b;
	case T_SHR: return uns ? a >> b : (u16)(x >> y);
	case '&': return a & b;
	case '|': return a | b;
	case '^': return a ^ b;
	case T_EQ: return a == b;
	case T_NE: return a != b;
	case '<': return uns ? a < b : x < y;
	case '>': return uns ? a > b : x > y;
	case T_LE: return uns ? a <= b : x <= y;
	case T_GE: return uns ? a >= b : x >= y;
	}
	return 0;
}

static u8 iscmp(u8 op);

/*
 *	Generate the operator. Normally DE is the left operand and HL the
 *	right one; with swap set HL is the left one and DE the right.
 *	For comparisons the result is a flag.
 */
static void setcmp(struct opd *o, u8 op)
{
	if (!iscmp(op))
		return;
	o->k = O_CMP;
	o->type = TY_INT;
	if (op == T_EQ)
		o->v = JP_Z;
	else if (op == T_NE)
		o->v = JP_NZ;
	else if (op == '<' || op == '>')
		o->v = JP_C;
	else
		o->v = JP_NC;
}

static void emitop(struct opd *o, u8 op, u8 uns, u8 swap)
{
	if (!nocode) {
		irop(I_OP);
		irb(op);
		irb(uns);
		irb(swap);
	}
	setcmp(o, op);
}

static u8 iscmp(u8 op)
{
	return op == T_EQ || op == T_NE || op == '<' || op == '>' || op == T_LE || op == T_GE;
}

/* Constant right operand: left in HL */
static void constop(struct opd *o, u8 op, u16 v, u8 uns)
{
	if (!nocode) {
		irop(I_CONST);
		irb(op);
		irw(v);
		irb(uns);
	}
	setcmp(o, op);
}

/*
 *	Combine two operands. If pushed is set the left operand is on the
 *	stack, otherwise it is simple.
 */
static void combine(struct opd *l, struct opd *r, u8 op, u8 pushed)
{
	u8 lt, rt, uns, rtype;
	u16 ls = 0, rs = 0, div = 0;

	if (l->k == O_CMP || r->k == O_CMP) {
		/* only happens with pushed set for l */
	}
	lt = decay(l->type);
	rt = decay(r->type);
	notlong(lt);
	notlong(rt);
	uns = unsignedop(l, r);
	rtype = arith(lt, rt);
	if (op == T_SHL || op == T_SHR) {
		/* the result has the type of the left operand */
		rtype = arith(lt, TY_INT);
		uns = rtype == TY_UINT;
	}
	if (op == '+' || op == '-') {
		if (isptr(lt) && !isptr(rt)) {
			rs = elsize(lt);
			rtype = lt;
		} else if (isptr(rt) && op == '+') {
			ls = elsize(rt);
			rtype = rt;
		} else if (isptr(lt) && isptr(rt)) {
			div = elsize(lt);
			rtype = TY_INT;
		}
	} else if (iscmp(op))
		rtype = TY_INT;

	if (!pushed && l->k == O_CON && r->k == O_CON) {
		l->v = fold(op, l->v * (ls ? ls : 1), r->v * (rs ? rs : 1), uns);
		l->type = rtype;
		return;
	}
	if (r->k == O_CON && rs)
		r->v *= rs, rs = 0;
	if (!pushed && r->k == O_CON && !ls) {
		tohl(l);
		constop(l, op, r->v, uns);
	} else {
		tohl(r);
		if (rs)
			scalehl(rs);
		if (pushed)
			gb(0xD1);	/* pop de */
		else
			tode(l);
		if (ls) {
			gb(0xEB);
			scalehl(ls);
			gb(0xEB);
		}
		emitop(l, op, uns, 0);
	}
	if (iscmp(op))
		return;
	l->k = O_REG;
	l->type = rtype;
	if (div) {
		if (div == 2)
			g3(0xCB, 0x2C, 0xCB), gb(0x1D);	/* sra h; rr l */
		else if (div > 1) {
			gb(0xEB);
			gld_hl(div);
			gcall(H_DIV);
		}
	}
}

void tobool(struct opd *o, u8 jumpif, u16 label)
{
	u8 c;
	if (o->k == O_CON) {
		if ((o->v != 0) == jumpif)
			gjp(0xC3, label);
		return;
	}
	if (o->k == O_CMP)
		c = o->v;
	else {
		tohl(o);
		g2(0x7C, 0xB5);		/* ld a,h; or l */
		c = JP_NZ;
	}
	if (!jumpif)
		c ^= 0x08;		/* z <-> nz, c <-> nc */
	gjp(c, label);
}

/*
 *	Primary expressions
 */
static u8 insizeof;

static void string(struct opd *o)
{
	u16 n = 1;
	o->k = O_SADR;
	o->sym = SEG_LIT;
	o->v = litpos;
	while (tok == T_STR) {
		u16 i;
		for (i = 0; i < strlen_; i++)
			lbyte(strbuf[i]);
		n += strlen_;
		next();
	}
	lbyte(0);
	/* Only sizeof needs to know it is an array */
	o->type = insizeof ? mktype(TK_ARRAY, TY_CHAR, n) : TY_CHARP;
}

static void primary(struct opd *o)
{
	struct name *n;
	struct local *l;

	o->v = 0;
	o->sym = 0;
	o->type = TY_INT;
	switch (tok) {
	case T_NUM:
		o->k = O_CON;
		o->v = tokval;
		if (tokval > 0x7FFF)
			o->type = TY_UINT;
		next();
		return;
	case T_STR:
		string(o);
		return;
	case T_ID:
		n = tokid();
		next();
		l = findlocal(n);
		if (l && l->cls != C_GLOBAL) {
			o->type = l->type;
			o->v = l->val;
			if (l->cls == C_LOCAL)
				o->k = O_LVAR;
			else if (l->cls == C_ENUM)
				o->k = O_CON;
			else {
				o->k = O_SVAR;
				o->sym = l->flags & F_DATA ? SEG_DATA : SEG_BSS;
			}
			return;
		}
		switch (n->cls) {
		case C_NONE:
			if (tok != '(') {
				errorn("undefined", n);
				o->k = O_CON;
				return;
			}
			n->cls = C_GLOBAL;
			n->type = mktype(TK_FUNC, TY_INT, 0);
		case C_GLOBAL:
			o->k = O_GVAR;
			o->sym = symref(n);
			o->type = n->type;
			return;
		case C_STATIC:
			o->k = O_SVAR;
			o->sym = n->flags & F_DATA ? SEG_DATA : SEG_BSS;
			o->v = n->val;
			o->type = n->type;
			return;
		case C_ENUM:
			o->k = O_CON;
			o->v = n->val;
			return;
		}
		errorn("bad use of", n);
		o->k = O_CON;
		return;
	}
	error("expression expected");
	next();
	o->k = O_CON;
}

/* *o */
static void indirect(struct opd *o)
{
	u8 t = decay(o->type);
	if (!isptr(t)) {
		error("pointer required");
		o->type = TY_INT;
		return;
	}
	t = deref(t);
	if (types[t].kind == TK_FUNC) {
		/* (*fp)() is the same as fp() */
		tohl(o);
		o->type = t;
		return;
	}
	if (o->k == O_GADR || o->k == O_SADR || o->k == O_LADR) {
		if (!isagg(o->type) || types[o->type].kind == TK_ARRAY) {
			o->k += O_GVAR - O_GADR;
			o->type = t;
			return;
		}
	}
	if (o->k >= O_GVAR && o->k <= O_LVAR && types[o->type].kind == TK_ARRAY) {
		/* the array itself is the lvalue of its first element */
		o->type = t;
		return;
	}
	tohl(o);
	o->k = O_IND;
	o->type = t;
}

static void addressof(struct opd *o)
{
	u8 t = o->type;
	farfix(o);
	switch (o->k) {
	case O_GVAR: case O_SVAR: case O_LVAR:
		o->k -= O_GVAR - O_GADR;
		break;
	case O_IND:
		o->k = O_REG;
		break;
	case O_REG:
		if (types[t].kind == TK_FUNC)
			break;
	default:
		error("cannot take address");
	}
	o->type = mktype(TK_PTR, t, 2);
}

static void member(struct opd *o)
{
	struct member *m;
	if (tok != T_ID) {
		error("member name expected");
		return;
	}
	m = findmember(o->type, tokname);
	next();
	if (!m) {
		error("no such member");
		return;
	}
	farfix(o);
	if (o->k == O_IND) {
		if (m->off) {
			gld_de(m->off);
			gb(0x19);
		}
	} else if (o->k >= O_GVAR && o->k <= O_LVAR) {
		o->v += m->off;
		if (farlocal(o))
			farfix(o);
	} else
		error("struct required");
	o->type = m->type;
}

static void call(struct opd *o)
{
	u8 direct, n = 0;
	u8 t = o->type;
	struct opd a;

	if (types[t].kind == TK_PTR)
		t = deref(t);
	if (types[t].kind != TK_FUNC) {
		error("not a function");
		t = mktype(TK_FUNC, TY_INT, 0);
	}
	direct = o->k == O_GVAR;
	if (!direct) {
		tohl(o);
		gb(0xE5);
	}
	if (tok != ')') {
		do {
			assign(&a);
			tohl(&a);
			notlong(a.type);
			gb(0xE5);		/* push hl */
			n++;
		} while (accept(','));
	}
	expect(')');
	if (n > 1) {
		g2(0x3E, n);		/* ld a,n */
		gcall(H_REV);
	}
	if (direct)
		gcallsym(o->sym);
	else {
		gld_hl(n * 2);
		g2(0x39, 0x7E);		/* add hl,sp; ld a,(hl) */
		g3(0x23, 0x66, 0x6F);	/* inc hl; ld h,(hl); ld l,a */
		gcall(H_JPHL);
		n++;
	}
	gaddsp(n * 2);
	o->k = O_REG;
	o->type = types[t].sub;
	if (ischar(o->type))
		extl(o->type);
}

static void incdec(struct opd *o, u8 inc, u8 post)
{
	u16 step = 1;
	u8 t = o->type;
	struct opd v;

	if (!islvalue(o)) {
		error("lvalue required");
		return;
	}
	if (isptr(t))
		step = elsize(t);
	farfix(o);
	memcpy(&v, o, sizeof(v));
	if (o->k == O_IND)
		gb(0xE5);		/* push hl (address) */
	tohl(&v);
	if (!inc)
		step = -step;
	constop(&v, '+', step, 1);
	if (o->k == O_IND)
		gb(0xD1);		/* pop de */
	store(o, !post);
	if (post)
		constop(&v, '-', step, 1);
	o->k = O_REG;
	o->type = decay(t);
}

static void postfix(struct opd *o)
{
	struct opd i;
	u8 pushed;
	for (;;) {
		switch (tok) {
		case '[':
			next();
			pushed = 0;
			if (!simple(o) || types[o->type].kind == TK_ARRAY && o->k == O_LVAR) {
				tohl(o);
				gb(0xE5);
				pushed = 1;
			}
			expr(&i);
			expect(']');
			combine(o, &i, '+', pushed);
			indirect(o);
			break;
		case '(':
			next();
			call(o);
			break;
		case '.':
			next();
			member(o);
			break;
		case T_ARROW:
			next();
			tohl(o);
			o->k = O_IND;
			o->type = deref(o->type);
			member(o);
			break;
		case T_INC:
		case T_DEC:
			incdec(o, tok == T_INC, 1);
			next();
			break;
		default:
			return;
		}
	}
}

void cast(struct opd *o, u8 t)
{
	if (t == TY_VOID) {
		if (o->k != O_CON)
			tohl(o);
		o->type = t;
		return;
	}
	notlong(t);
	if (o->k == O_CON) {
		if (t == TY_CHAR)
			o->v &= 0xFF;
		else if (t == TY_SCHAR)
			o->v = (s16)(signed char)o->v;
		o->type = t;
		return;
	}
	if (o->k == O_GADR || o->k == O_SADR || o->k == O_LADR) {
		if (!ischar(t)) {
			o->type = t;
			return;
		}
	}
	tohl(o);
	if (ischar(t) && !ischar(o->type))
		extl(t);
	o->type = t;
}

static void unary(struct opd *o)
{
	u8 op = tok, t;
	switch (tok) {
	case T_INC:
	case T_DEC:
		next();
		unary(o);
		incdec(o, op == T_INC, 0);
		return;
	case '-':
	case '~':
	case '!':
	case '+':
		next();
		unary(o);
		if (o->k == O_CON) {
			if (op == '-')
				o->v = -o->v;
			else if (op == '~')
				o->v = ~o->v;
			else if (op == '!')
				o->v = !o->v, o->type = TY_INT;
			return;
		}
		if (op == '+')
			return;
		if (op == '!') {
			if (o->k == O_CMP) {
				o->v ^= 0x08;
				return;
			}
			tohl(o);
			g2(0x7C, 0xB5);		/* ld a,h; or l */
			o->k = O_CMP;
			o->v = JP_Z;
			o->type = TY_INT;
			return;
		}
		tohl(o);
		notlong(o->type);
		if (op == '-') {
			g3(0xAF, 0x95, 0x6F);	/* xor a; sub l; ld l,a */
			g3(0x9F, 0x94, 0x67);	/* sbc a,a; sub h; ld h,a */
		} else {
			g3(0x7D, 0x2F, 0x6F);	/* ld a,l; cpl; ld l,a */
			g3(0x7C, 0x2F, 0x67);
		}
		o->type = arith(o->type, TY_INT);
		return;
	case '*':
		next();
		unary(o);
		indirect(o);
		return;
	case '&':
		next();
		unary(o);
		addressof(o);
		return;
	case K_SIZEOF:
		next();
		nocode++;
		insizeof++;
		if (tok == '(') {
			next();
			if (is_typename())
				t = typename();
			else {
				expr(o);
				postfix(o);
				t = o->type;
			}
			expect(')');
		} else {
			unary(o);
			t = o->type;
		}
		nocode--;
		insizeof--;
		o->k = O_CON;
		o->v = tsize(t);
		o->type = TY_UINT;
		return;
	case '(':
		next();
		if (is_typename()) {
			t = typename();
			expect(')');
			unary(o);
			cast(o, t);
			return;
		}
		expr(o);
		expect(')');
		postfix(o);
		return;
	}
	primary(o);
	postfix(o);
}

/*
 *	Binary operators by precedence
 */
static u8 prec(u8 t)
{
	switch (t) {
	case '*': case '/': case '%':
		return 10;
	case '+': case '-':
		return 9;
	case T_SHL: case T_SHR:
		return 8;
	case '<': case '>': case T_LE: case T_GE:
		return 7;
	case T_EQ: case T_NE:
		return 6;
	case '&':
		return 5;
	case '^':
		return 4;
	case '|':
		return 3;
	case T_ANDAND:
		return 2;
	case T_OROR:
		return 1;
	}
	return 0;
}

static void logical(struct opd *o, u8 op, u8 p)
{
	struct opd r;
	u16 l1 = newlabel(), lend = newlabel();
	u8 isand = op == T_ANDAND;

	if (o->k == O_CON && nocode) {
		binexpr(&r, p + 1);
		if (r.k == O_CON) {
			o->v = isand ? o->v && r.v : o->v || r.v;
			return;
		}
	}
	tobool(o, !isand, l1);
	binexpr(&r, p + 1);
	tobool(&r, !isand, l1);
	gld_hl(isand);
	gjp(0xC3, lend);
	setlabel(l1);
	gld_hl(!isand);
	setlabel(lend);
	o->k = O_REG;
	o->type = TY_INT;
}

static void binexpr(struct opd *o, u8 minprec)
{
	u8 op, p, pushed;
	struct opd r;

	unary(o);
	while ((p = prec(tok)) >= minprec && p) {
		op = tok;
		next();
		if (op == T_ANDAND || op == T_OROR) {
			logical(o, op, p);
			continue;
		}
		pushed = 0;
		if (!simple(o)) {
			tohl(o);
			gb(0xE5);
			pushed = 1;
		}
		binexpr(&r, p + 1);
		combine(o, &r, op, pushed);
	}
}

void condexpr(struct opd *o)
{
	struct opd a, b;
	u16 lelse, lend;

	binexpr(o, 1);
	if (tok != '?')
		return;
	next();
	if (o->k == O_CON && nocode) {
		expr(&a);
		expect(':');
		condexpr(&b);
		memcpy(o, o->v ? &a : &b, sizeof(*o));
		return;
	}
	lelse = newlabel();
	lend = newlabel();
	tobool(o, 0, lelse);
	expr(&a);
	tohl(&a);
	gjp(0xC3, lend);
	expect(':');
	setlabel(lelse);
	condexpr(&b);
	tohl(&b);
	setlabel(lend);
	o->k = O_REG;
	o->type = isptr(b.type) && !isptr(a.type) ? b.type : a.type;
}

void assign(struct opd *o)
{
	struct opd r, v;
	u8 op = tok, t;

	condexpr(o);
	op = tok;
	if (op != '=' && (op < T_ADDEQ || op > T_SHREQ))
		return;
	next();
	t = o->type;
	if (!islvalue(o)) {
		error("lvalue required");
		assign(&r);
		return;
	}
	farfix(o);
	if (op == '=') {
		if (o->k == O_IND)
			gb(0xE5);
		assign(&r);
		tohl(&r);
		if (o->k == O_IND)
			gb(0xD1);
		store(o, 1);
	} else {
		static const u8 opmap[] = { '+', '-', '*', '/', '%', '&', '|', '^', T_SHL, T_SHR };
		op = opmap[op - T_ADDEQ];
		memcpy(&v, o, sizeof(v));
		if (o->k == O_IND)
			gb(0xE5);		/* the address */
		tohl(&v);
		gb(0xE5);			/* the old value */
		assign(&r);
		combine(&v, &r, op, 1);
		tohl(&v);
		if (o->k == O_IND)
			gb(0xD1);
		store(o, 1);
	}
	o->k = O_REG;
	o->type = decay(t);
}

void expr(struct opd *o)
{
	assign(o);
	while (accept(','))
		assign(o);
}

u16 constexpr(void)
{
	struct opd o;
	nocode++;
	condexpr(&o);
	nocode--;
	if (o.k != O_CON)
		error("constant expected");
	return o.v;
}
