/*
 *	scc: statements, functions and initializers
 */

#include <string.h>
#include "scc.h"

s16 frameoff;
u8 functype;
u8 infunc;

static u16 retlabel;
static u16 brklabel = 0xFFFF;
static u16 contlabel = 0xFFFF;

/* The cases of the switch being compiled */
struct swcase {
	u16 val;
	u16 label;
};
static struct swcase *cases;
static u8 ncases;
static u16 deflabel;
static u8 inswitch;

/* goto labels */
struct glabel {
	struct name *nm;
	u16 label;
	u8 defined;
};
static struct glabel glabels[16];
static u8 nglabels;


static void statement(void);

static u16 gotolabel(struct name *n, u8 define)
{
	u8 i;
	for (i = 0; i < nglabels; i++)
		if (glabels[i].nm == n)
			break;
	if (i == nglabels) {
		if (i == 16)
			fatal("too many goto labels");
		glabels[i].nm = n;
		glabels[i].label = newlabel();
		glabels[i].defined = 0;
		nglabels++;
	}
	if (define) {
		if (glabels[i].defined)
			errorn("label redefined", n);
		glabels[i].defined = 1;
	}
	return glabels[i].label;
}

static void exprstmt(void)
{
	struct opd o;
	expr(&o);
	expect(';');
}

static void cond(u8 jumpif, u16 label)
{
	struct opd o;
	expect('(');
	expr(&o);
	expect(')');
	tobool(&o, jumpif, label);
}

static void loopbody(u16 brk, u16 cont)
{
	u16 ob = brklabel, oc = contlabel;
	brklabel = brk;
	contlabel = cont;
	statement();
	brklabel = ob;
	contlabel = oc;
}

static void compound(void)
{
	u8 save = nlocals, sscope = scopebase;
	scopebase = nlocals;
	while (tok != '}' && tok != T_EOF) {
		if (is_typename())
			declaration(1);
		else
			statement();
	}
	expect('}');
	nlocals = save;
	scopebase = sscope;
}

static void switchstmt(void)
{
	struct opd o;
	struct swcase table[48];
	struct swcase *ocases = cases;
	u8 oncases = ncases, oinswitch = inswitch;
	u16 odef = deflabel, obrk = brklabel;
	u16 test = newlabel(), brk = newlabel();
	u8 i;

	expect('(');
	expr(&o);
	expect(')');
	tohl(&o);
	gjp(0xC3, test);
	cases = table;
	ncases = 0;
	inswitch = 1;
	deflabel = brk;
	brklabel = brk;
	statement();
	gjp(0xC3, brk);
	/* The dispatch: call the helper with the table after the call */
	setlabel(test);
	gcall(H_SWITCH);
	gw(ncases);
	for (i = 0; i < ncases; i++) {
		gw(table[i].val);
		glabword(table[i].label);
	}
	glabword(deflabel);
	setlabel(brk);
	cases = ocases;
	ncases = oncases;
	inswitch = oinswitch;
	deflabel = odef;
	brklabel = obrk;
}

static void statement(void)
{
	struct opd o;
	u16 l1, l2, l3;
	struct name *n;

	switch (tok) {
	case '{':
		next();
		compound();
		return;
	case ';':
		next();
		return;
	case K_IF:
		next();
		l1 = newlabel();
		cond(0, l1);
		statement();
		if (accept(K_ELSE)) {
			l2 = newlabel();
			gjp(0xC3, l2);
			setlabel(l1);
			statement();
			setlabel(l2);
		} else
			setlabel(l1);
		return;
	case K_WHILE:
		next();
		l1 = newlabel();
		l2 = newlabel();
		setlabel(l1);
		cond(0, l2);
		loopbody(l2, l1);
		gjp(0xC3, l1);
		setlabel(l2);
		return;
	case K_DO:
		next();
		l1 = newlabel();
		l2 = newlabel();
		l3 = newlabel();
		setlabel(l1);
		loopbody(l3, l2);
		expect(K_WHILE);
		setlabel(l2);
		cond(1, l1);
		setlabel(l3);
		expect(';');
		return;
	case K_FOR:
		next();
		expect('(');
		if (tok != ';')
			expr(&o);
		expect(';');
		l1 = newlabel();	/* test */
		l2 = newlabel();	/* step */
		l3 = newlabel();	/* exit */
		{
			u16 body = newlabel();
			setlabel(l1);
			if (tok != ';') {
				expr(&o);
				tobool(&o, 0, l3);
			}
			expect(';');
			gjp(0xC3, body);
			setlabel(l2);
			if (tok != ')')
				expr(&o);
			expect(')');
			gjp(0xC3, l1);
			setlabel(body);
			loopbody(l3, l2);
			gjp(0xC3, l2);
			setlabel(l3);
		}
		return;
	case K_SWITCH:
		next();
		switchstmt();
		return;
	case K_CASE:
		next();
		if (!inswitch)
			error("case outside switch");
		l1 = constexpr();
		expect(':');
		if (ncases == 48)
			fatal("too many cases");
		cases[ncases].val = l1;
		cases[ncases].label = newlabel();
		setlabel(cases[ncases++].label);
		statement();
		return;
	case K_DEFAULT:
		next();
		expect(':');
		if (!inswitch)
			error("default outside switch");
		deflabel = newlabel();
		setlabel(deflabel);
		statement();
		return;
	case K_BREAK:
		next();
		if (brklabel == 0xFFFF)
			error("break outside loop");
		else
			gjp(0xC3, brklabel);
		expect(';');
		return;
	case K_CONTINUE:
		next();
		if (contlabel == 0xFFFF)
			error("continue outside loop");
		else
			gjp(0xC3, contlabel);
		expect(';');
		return;
	case K_RETURN:
		next();
		if (tok != ';') {
			expr(&o);
			cast(&o, types[functype].sub);
			if (o.type != TY_VOID)
				tohl(&o);
		}
		gjp(0xC3, retlabel);
		expect(';');
		return;
	case K_GOTO:
		next();
		if (tok == T_ID) {
			gjp(0xC3, gotolabel(tokid(), 0));
			next();
		} else
			error("label expected");
		expect(';');
		return;
	case T_ID:
		/* A label ? */
		n = tokid();
		next();
		if (tok == ':') {
			next();
			setlabel(gotolabel(n, 1));
			statement();
			return;
		}
		/* No: put the name back by hand */
		{
			u8 t = tok;
			tok = T_ID;
			tokname = n;
			unput(t);
		}
		break;
	}
	exprstmt();
}

void funcbody(struct name *n, u8 type)
{
	u8 i;
	struct local *l;
	u16 sym = symref(n);

	if (n->flags & F_DEFINED)
		errorn("redefined", n);
	n->flags |= F_DEFINED;
	n->type = type;
	defsym(sym, SEG_CODE, 0, !(n->flags & F_STATIC));
	functype = type;
	infunc = 1;
	nlocals = 0;
	scopebase = 0;
	frameoff = 0;
	nglabels = 0;
	for (i = 0; i < nparams; i++) {
		if (params[i].id == NOID)
			continue;
		l = addlocal(idp(params[i].id), C_LOCAL, params[i].type);
		l->val = 4 + 2 * i;
	}
	nocode = 0;
	funcbegin(sym);
	retlabel = newlabel();
	expect('{');
	scopebase = nlocals;
	compound();
	if (strcmp(idname(n), "main") == 0)
		gld_hl(0);
	setlabel(retlabel);
	for (i = 0; i < nglabels; i++)
		if (!glabels[i].defined)
			errorn("undefined label", glabels[i].nm);
	funcend(-frameoff);
	nocode = 1;
	infunc = 0;
	nlocals = 0;
}

/*
 *	Local initializers: only scalars
 */
void initlocal(u16 off, u8 type)
{
	struct opd o;
	if (types[type].kind == TK_ARRAY || types[type].kind == TK_STRUCT) {
		error("local array and struct initializers are not supported");
		return;
	}
	assign(&o);
	cast(&o, type);
	tohl(&o);
	if (off < (u16)-128) {
		g3(0xDD, 0xE5, 0xD1);	/* push ix; pop de */
		gb(0xE5);
		gld_hl(off);
		g2(0x19, 0xEB);		/* add hl,de; ex de,hl */
		gb(0xE1);
		if (ischar(type))
			g2(0x7D, 0x12);
		else {
			g2(0x7D, 0x12);
			g3(0x13, 0x7C, 0x12);
		}
		return;
	}
	gix(0x75, off);
	if (!ischar(type))
		gix(0x74, off + 1);
}

/*
 *	Global initializers: data is written in order.
 */
static void initscalar(u8 type)
{
	struct opd o;
	u16 sz = tsize(type);
	nocode++;
	assign(&o);
	nocode--;
	/* string literals still go out: only code is suppressed */
	if (o.k == O_CON) {
		if (sz == 1)
			dbyte(o.v);
		else if (sz == 2)
			dword(o.v);
		else {
			dword(o.v);
			dword((s16)o.v < 0 && issigned(type) ? 0xFFFF : 0);
		}
		return;
	}
	if (sz != 2 || (o.k != O_GADR && o.k != O_SADR)) {
		error("constant expected");
		while (sz--)
			dbyte(0);
		return;
	}
	if (o.k == O_GADR)
		dsym(o.sym, o.v);
	else
		drel(o.sym, o.v);
}

static void pad(u16 n)
{
	while (n--)
		dbyte(0);
}

static u16 initdata(u8 type);

/* Initialize an aggregate from a list of values, braces optional */
static u16 initagg(u8 type, u8 braced)
{
	u16 done = 0, n = 0, sz;
	u8 kind = types[type].kind;
	struct member *m = NULL;
	u8 et;

	if (kind == TK_STRUCT)
		m = structs[types[type].sub].first;
	sz = tsize(type);
	while (tok != '}' && tok != T_EOF) {
		if (kind == TK_ARRAY) {
			et = types[type].sub;
			if (sz && done >= sz)
				break;
		} else {
			if (!m)
				break;
			pad(m->off - done);
			done = m->off;
			et = m->type;
			m = m->next;
		}
		done += initdata(et);
		n++;
		if (!accept(','))
			break;
		if (!braced && (kind == TK_ARRAY ? sz && done >= sz : !m))
			break;
	}
	if (kind == TK_ARRAY && !sz)
		return done;
	pad(sz - done);
	return sz;
}

static u16 initdata(u8 type)
{
	u8 kind = types[type].kind;
	u16 sz = tsize(type), n;

	if (kind == TK_ARRAY && ischar(types[type].sub) && tok == T_STR) {
		/* char x[] = "string" */
		n = 0;
		while (tok == T_STR) {
			u16 i;
			for (i = 0; i < strlen_; i++, n++)
				if (!sz || n < sz)
					dbyte(strbuf[i]);
			next();
		}
		if (!sz)
			sz = n + 1;
		if (n < sz)
			pad(sz - n);
		return sz;
	}
	if (kind == TK_ARRAY || kind == TK_STRUCT) {
		if (accept('{')) {
			n = initagg(type, 1);
			accept(',');
			expect('}');
			return n;
		}
		return initagg(type, 0);
	}
	if (accept('{')) {
		initscalar(type);
		expect('}');
	} else
		initscalar(type);
	return sz;
}

u8 initglobal(u8 type)
{
	u16 n = initdata(type);
	if (types[type].kind == TK_ARRAY && !tsize(type))
		type = mktype(TK_ARRAY, types[type].sub, n);
	return type;
}
