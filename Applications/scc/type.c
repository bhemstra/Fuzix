/*
 *	scc: types and declarations
 */

#include <string.h>
#include "scc.h"

struct type types[256] = {
	{ 0, 0, 0 },
	{ TK_SCALAR, 0, 0 },		/* void */
	{ TK_SCALAR, 0, 1 },		/* char */
	{ TK_SCALAR, 0, 1 },		/* signed char */
	{ TK_SCALAR, 0, 2 },		/* int */
	{ TK_SCALAR, 0, 2 },		/* unsigned */
	{ TK_SCALAR, 0, 4 },		/* long */
	{ TK_SCALAR, 0, 4 },		/* unsigned long */
	{ TK_SCALAR, 0, 4 },		/* float / double */
	{ TK_PTR, TY_CHAR, 2 },		/* char * */
};
u8 ntypes = TY_NTYPES;

struct strct structs[64];
u8 nstructs;

u8 mktype(u8 kind, u8 sub, u16 size)
{
	u8 i;
	struct type *t = types + 1;
	for (i = 1; i < ntypes; i++, t++)
		if (t->kind == kind && t->sub == sub && t->size == size)
			return i;
	if (ntypes == 255)
		fatal("too many types");
	t->kind = kind;
	t->sub = sub;
	t->size = size;
	return ntypes++;
}

u8 isptr(u8 t)
{
	return types[t].kind == TK_PTR;
}

u8 isint(u8 t)
{
	return t >= TY_CHAR && t <= TY_UINT;
}

u8 ischar(u8 t)
{
	return t == TY_CHAR || t == TY_SCHAR;
}

u8 issigned(u8 t)
{
	return t == TY_SCHAR || t == TY_INT || t == TY_LONG;
}

u16 tsize(u8 t)
{
	if (types[t].kind == TK_STRUCT)
		return structs[types[t].sub].size;
	return types[t].size;
}

/* Size of what a pointer or array points to (1 for void *) */
u16 elsize(u8 t)
{
	u16 s = tsize(types[t].sub);
	return s ? s : 1;
}

u8 deref(u8 t)
{
	return types[t].sub;
}

/* Arrays become pointers to their first element, functions pointers */
u8 decay(u8 t)
{
	if (types[t].kind == TK_ARRAY)
		return mktype(TK_PTR, types[t].sub, 2);
	if (types[t].kind == TK_FUNC)
		return mktype(TK_PTR, t, 2);
	return t;
}

/*
 *	Local symbols
 */
struct local locals[64];
u8 nlocals;
u8 scopebase;

struct local *findlocal(struct name *n)
{
	struct local *l = locals + nlocals;
	while (l-- != locals)
		if (l->nm == n)
			return l;
	return NULL;
}

struct local *addlocal(struct name *n, u8 cls, u8 type)
{
	struct local *l;
	for (l = locals + scopebase; l < locals + nlocals; l++)
		if (l->nm == n)
			errorn("redeclared", n);
	if (nlocals == 64)
		fatal("too many locals");
	l = locals + nlocals++;
	l->nm = n;
	l->cls = cls;
	l->type = type;
	l->flags = 0;
	l->val = 0;
	return l;
}

/* Is this identifier a typedef name in the current scope */
static u8 istypedef(struct name *n)
{
	struct local *l;
	if (!n)
		return 0;
	l = findlocal(n);
	if (l)
		return l->cls == C_TYPEDEF;
	return n->cls == C_TYPEDEF;
}

static u8 typedeftype(struct name *n)
{
	struct local *l = findlocal(n);
	if (l)
		return l->type;
	return n->type;
}

u8 is_typename(void)
{
	if (tok >= K_FIRST && tok <= K_LAST) {
		switch (tok) {
		case K_AUTO: case K_CHAR: case K_CONST: case K_DOUBLE:
		case K_ENUM: case K_EXTERN: case K_FLOAT: case K_INT:
		case K_LONG: case K_REGISTER: case K_SHORT: case K_SIGNED:
		case K_STATIC: case K_STRUCT: case K_TYPEDEF: case K_UNION:
		case K_UNSIGNED: case K_VOID: case K_VOLATILE:
			return 1;
		}
		return 0;
	}
	return tok == T_ID && istypedef(tokname);
}

/*
 *	struct and union
 */
struct member *findmember(u8 t, struct name *n)
{
	struct member *m;
	if (types[t].kind != TK_STRUCT)
		return NULL;
	for (m = structs[types[t].sub].first; m; m = m->next)
		if (m->nm == n)
			return m;
	return NULL;
}

static u8 structdecl(u8 isunion)
{
	struct name *tag = NULL;
	struct strct *s;
	struct member *m, **mp;
	u8 sn;
	u8 bt, t, cls;
	struct name *mn;
	u16 off = 0, sz;

	if (tok == T_ID) {
		tag = tokid();
		next();
	}
	if (tag && tag->tag && tok != '{')
		return mktype(TK_STRUCT, tag->tag - 1, 0);
	/* A new struct: define or forward declare */
	if (tag && tag->tag && !structs[tag->tag - 1].defined)
		sn = tag->tag - 1;
	else {
		if (nstructs == 64)
			fatal("too many structs");
		sn = nstructs++;
		if (tag)
			tag->tag = sn + 1;
	}
	s = structs + sn;
	if (!accept('{'))
		return mktype(TK_STRUCT, sn, 0);
	if (s->defined)
		error("struct redefined");
	mp = &s->first;
	while (tok != '}' && tok != T_EOF) {
		bt = basetype(&cls);
		if (!bt) {
			error("member type expected");
			next();
			continue;
		}
		do {
			t = declarator(bt, &mn, 0);
			if (tok == ':')
				fatal("bit fields are not supported");
			sz = tsize(t);
			m = alloc(sizeof(struct member));
			m->nm = mn;
			m->type = t;
			m->off = isunion ? 0 : off;
			*mp = m;
			mp = &m->next;
			if (isunion) {
				if (sz > off)
					off = sz;
			} else
				off += sz;
		} while (accept(','));
		expect(';');
	}
	expect('}');
	s->size = off;
	s->defined = 1;
	return mktype(TK_STRUCT, sn, 0);
}

static void enumdecl(void)
{
	u16 v = 0;
	struct name *n;
	struct local *l;
	if (tok == T_ID)
		next();
	if (!accept('{'))
		return;
	while (tok == T_ID) {
		n = tokid();
		next();
		if (accept('='))
			v = constexpr();
		if (infunc) {
			l = addlocal(n, C_ENUM, TY_INT);
			l->val = v;
		} else {
			n->cls = C_ENUM;
			n->type = TY_INT;
			n->val = v;
		}
		v++;
		if (!accept(','))
			break;
	}
	expect('}');
}

/*
 *	Storage class and type specifiers. Returns 0 if there were none.
 */
u8 basetype(u8 *cls)
{
	u8 t = 0, sign = 0, sz = 0, any = 0;
	*cls = 0;
	for (;;) {
		switch (tok) {
		case K_STATIC: case K_EXTERN: case K_TYPEDEF:
			*cls = tok;
		case K_AUTO: case K_REGISTER: case K_CONST: case K_VOLATILE:
			break;
		case K_SIGNED:
			sign = 1;
			break;
		case K_UNSIGNED:
			sign = 2;
			break;
		case K_SHORT:
			sz = 1;
			break;
		case K_LONG:
			sz = 2;
			break;
		case K_VOID:
			t = TY_VOID;
			break;
		case K_CHAR:
			t = TY_CHAR;
			break;
		case K_INT:
			if (!t)
				t = TY_INT;
			break;
		case K_FLOAT: case K_DOUBLE:
			t = TY_FLOAT;
			break;
		case K_STRUCT: case K_UNION:
			{
				u8 u = tok == K_UNION;
				next();
				t = structdecl(u);
				any = 1;
				continue;
			}
		case K_ENUM:
			next();
			enumdecl();
			t = TY_INT;
			any = 1;
			continue;
		case T_ID:
			if (!t && !sign && !sz && istypedef(tokname)) {
				t = typedeftype(tokname);
				break;
			}
		default:
			if (!any && !t && !sign && !sz && !*cls)
				return 0;
			if (t == TY_CHAR) {
				if (sign == 1)
					t = TY_SCHAR;
			} else if (t == 0 || t == TY_INT) {
				if (sz == 2)
					t = sign == 2 ? TY_ULONG : TY_LONG;
				else
					t = sign == 2 ? TY_UINT : TY_INT;
			}
			return t;
		}
		any = 1;
		next();
	}
}

/*
 *	Declarators. The parts are collected as a list of operations to apply
 *	to the base type, then applied in order.
 */
#define D_PTR	0
#define D_ARRAY	1
#define D_FUNC	2

struct dop {
	u8 op;
	u16 n;
};

/*
 *	Parameters of the last parameter list (for a function definition).
 *	Their names are kept as text until a function body needs them.
 */
struct param params[16];
u8 nparams;
u8 krparams;
static u16 pname;		/* name found by an abstract declarator */

static void paramlist(void)
{
	struct param p[16];
	u8 n = 0, bt, cls, t;
	struct name *nm;
	u16 pn, opname = pname;
	u8 kr = 0;

	while (tok != ')' && tok != T_EOF) {
		if (tok == T_ELLIPSIS) {
			next();
			break;
		}
		pname = NOID;
		if (tok == T_ID && !istypedef(tokname)) {
			/* K&R style identifier list */
			pname = tokname->id;
			next();
			t = TY_INT;
			kr = 1;
		} else {
			bt = basetype(&cls);
			if (!bt)
				bt = TY_INT;
			t = declarator(bt, &nm, 1);
		}
		pn = pname;
		/* f(void) */
		if (t == TY_VOID && pn == NOID && n == 0 && tok == ')')
			break;
		if (types[t].kind == TK_ARRAY)
			t = mktype(TK_PTR, types[t].sub, 2);
		if (types[t].kind == TK_FUNC)
			t = mktype(TK_PTR, t, 2);
		if (n < 16) {
			p[n].id = pn;
			p[n].type = t;
			n++;
		}
		if (!accept(','))
			break;
	}
	expect(')');
	memcpy(params, p, sizeof(p));
	nparams = n;
	krparams = kr;
	pname = opname;
}

static u8 dcl(struct dop *ops, struct name **np, u8 abstract)
{
	u8 nstar = 0, n = 0, ni = 0, i;
	struct dop inner[8];
	struct dop suf[8];
	u8 ns = 0;

	while (tok == '*' || tok == K_CONST || tok == K_VOLATILE) {
		if (tok == '*')
			nstar++;
		next();
	}
	if (tok == '(') {
		next();
		/* A nested declarator or (for abstract ones) a parameter list */
		if (tok == '*' || tok == '(' || (tok == T_ID && !istypedef(tokname))) {
			ni = dcl(inner, np, abstract);
			expect(')');
		} else {
			paramlist();
			suf[ns].op = D_FUNC;
			ns++;
		}
	} else if (tok == T_ID) {
		if (abstract)
			pname = tokname->id;
		else
			*np = tokid();
		next();
	} else if (!abstract)
		error("identifier expected");
	for (;;) {
		if (accept('[')) {
			suf[ns].n = 0;
			if (tok != ']')
				suf[ns].n = constexpr();
			expect(']');
		} else if (accept('(')) {
			paramlist();
			suf[ns].op = D_FUNC;
			ns++;
			continue;
		} else
			break;
		suf[ns].op = D_ARRAY;
		if (ns < 7)
			ns++;
	}
	while (nstar--) {
		ops[n].op = D_PTR;
		n++;
	}
	while (ns--)
		memcpy(&ops[n++], &suf[ns], sizeof(struct dop));
	for (i = 0; i < ni; i++)
		memcpy(&ops[n++], &inner[i], sizeof(struct dop));
	if (n > 8)
		fatal("declarator too complex");
	return n;
}

u8 declarator(u8 t, struct name **np, u8 abstract)
{
	struct dop ops[8];
	u8 n, i;
	*np = NULL;
	n = dcl(ops, np, abstract);
	for (i = 0; i < n; i++) {
		switch (ops[i].op) {
		case D_PTR:
			t = mktype(TK_PTR, t, 2);
			break;
		case D_ARRAY:
			t = mktype(TK_ARRAY, t, ops[i].n * tsize(t));
			break;
		case D_FUNC:
			t = mktype(TK_FUNC, t, 0);
			break;
		}
	}
	return t;
}

u8 typename(void)
{
	u8 cls, t;
	struct name *n;
	t = basetype(&cls);
	return declarator(t, &n, 1);
}

/*
 *	Make sure a global name has an object symbol
 */
u16 symref(struct name *n)
{
	char *s;
	if (!(n->flags & F_HASSYM)) {
		const char *t = idname(n);
		s = alloc(strlen(t) + 2);
		*s = '_';
		strcpy(s + 1, t);
		newsym(n, s);
	}
	return n->val;
}

static void globalvar(struct name *n, u8 cls, u8 t)
{
	u8 isstatic = cls == K_STATIC;
	if (cls == K_EXTERN) {
		if (n->cls != C_GLOBAL && n->cls != C_STATIC) {
			n->cls = C_GLOBAL;
			n->type = t;
		}
		return;
	}
	if (n->cls == C_GLOBAL && (n->flags & F_DEFINED)) {
		if (tok != '=') {
			/* A repeated tentative definition */
			return;
		}
		errorn("redefined", n);
	}
	n->type = t;
	if (tok == '=') {
		next();
		if (isstatic) {
			n->cls = C_STATIC;
			n->flags |= F_DATA | F_DEFINED;
			n->val = datapos;
		} else {
			n->cls = C_GLOBAL;
			n->flags |= F_DEFINED;
			defsym(symref(n), SEG_DATA, datapos, 1);
		}
		/* Arrays without a size take it from the initializer */
		n->type = initglobal(n->type);
		return;
	}
	if (types[t].kind == TK_FUNC)
		return;
	if (isstatic) {
		n->cls = C_STATIC;
		n->flags |= F_DEFINED;
		n->val = bsspos;
	} else {
		n->cls = C_GLOBAL;
		n->flags |= F_DEFINED;
		defsym(symref(n), SEG_BSS, bsspos, 1);
	}
	if (!tsize(t))
		errorn("unknown size", n);
	bsspos += tsize(t);
}

static void localvar(struct name *n, u8 cls, u8 t)
{
	struct local *l;
	u16 sz = tsize(t);

	if (cls == K_EXTERN || types[t].kind == TK_FUNC) {
		l = addlocal(n, C_GLOBAL, t);
		if (n->cls != C_GLOBAL && n->cls != C_STATIC) {
			n->cls = C_GLOBAL;
			n->type = t;
		}
		return;
	}
	if (cls == K_STATIC) {
		l = addlocal(n, C_STATIC, t);
		if (accept('=')) {
			l->flags = F_DATA;
			l->val = datapos;
			l->type = initglobal(t);
		} else {
			l->val = bsspos;
			bsspos += sz;
		}
		return;
	}
	if (!sz)
		errorn("unknown size", n);
	frameoff -= sz;
	l = addlocal(n, C_LOCAL, t);
	l->val = frameoff;
	if (accept('='))
		initlocal(frameoff, t);
}

/*
 *	A declaration, at file scope or in a block
 */
void declaration(u8 local)
{
	u8 bt, cls, t, first = 1;
	struct name *n;
	struct local *l;
	u8 i;

	bt = basetype(&cls);
	if (!bt)
		bt = TY_INT;
	if (accept(';'))
		return;
	do {
		t = declarator(bt, &n, 0);
		if (!n)
			continue;
		if (cls == K_TYPEDEF) {
			if (local) {
				l = addlocal(n, C_TYPEDEF, t);
			} else {
				n->cls = C_TYPEDEF;
				n->type = t;
			}
			continue;
		}
		if (local) {
			localvar(n, cls, t);
			continue;
		}
		if (types[t].kind == TK_FUNC) {
			if (n->cls != C_GLOBAL || !(n->flags & F_DEFINED))
				n->type = t;
			if (n->cls != C_GLOBAL) {
				n->cls = C_GLOBAL;
				if (cls == K_STATIC)
					n->flags |= F_STATIC;
			}
			if (first && (tok == '{' || (krparams && is_typename()))) {
				/* K&R parameter declarations */
				while (krparams && is_typename()) {
					u8 kbt, kcls, kt;
					struct name *kn;
					kbt = basetype(&kcls);
					do {
						kt = declarator(kbt, &kn, 0);
						for (i = 0; i < nparams; i++)
							if (kn && params[i].id == kn->id)
								params[i].type = kt;
					} while (accept(','));
					expect(';');
				}
				funcbody(n, t);
				return;
			}
			continue;
		}
		globalvar(n, cls, t);
		first = 0;
	} while (accept(','));
	expect(';');
}
