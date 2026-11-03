/*
 *	scc - a small C compiler for Fuzix on the Z80
 *
 *	One pass: the parser generates Z80 machine code as it goes and writes
 *	a Fuzix (Bintools) relocatable object file directly, so no assembler
 *	is needed. The code follows the Fuzix C compiler ABI so the objects
 *	link with the standard C library:
 *
 *	- arguments on the stack, first argument at the lowest address,
 *	  char arguments widened to a word, the caller removes them
 *	- the result in HL
 *	- BC, IX and IY preserved (scc uses IX as frame pointer)
 *	- char is unsigned, int is 16 bits
 *
 *	It is written to fit in a 32K process, so the tables are small and
 *	everything lives in one memory arena.
 */

#include <stdint.h>
#include "ir.h"


/*
 *	Names. scc0 numbers the identifiers; the record holds the file scope
 *	meaning of the name and its struct tag. The text is in a file.
 */
struct name {
	u8 cls;			/* C_xxx */
	u8 type;		/* type index */
	u8 flags;		/* F_xxx */
	u8 tag;			/* struct tag + 1, 0 if none */
	u16 val;		/* object symbol, offset, or enum value */
	u16 id;			/* identifier number (see scc0) */
};

#define C_NONE		0
#define C_KEYWORD	1	/* val is the token */
#define C_TYPEDEF	2
#define C_GLOBAL	3	/* val is the object symbol index */
#define C_STATIC	4	/* static data: val is the offset */
#define C_ENUM		5	/* val is the value */
#define C_LOCAL		6	/* (locals only) val is the frame offset */

#define F_DEFINED	1	/* storage allocated / function body seen */
#define F_DATA		2	/* C_STATIC: in data, else bss */
#define F_STATIC	4	/* file scope static (not exported) */
#define F_HASSYM	8	/* has an object symbol */

/*
 *	Types. Index into a table; the base types have fixed slots.
 */
struct type {
	u8 kind;
	u8 sub;		/* pointed to / element / return type, struct no */
	u16 size;
};

#define TY_VOID		1
#define TY_CHAR		2	/* unsigned */
#define TY_SCHAR	3
#define TY_INT		4
#define TY_UINT		5
#define TY_LONG		6	/* declarations only */
#define TY_ULONG	7
#define TY_FLOAT	8	/* declarations only */
#define TY_CHARP	9	/* char * */
#define TY_NTYPES	10

#define TK_SCALAR	1	/* base types: void char int long float */
#define TK_PTR		2
#define TK_ARRAY		3
#define TK_FUNC		4
#define TK_STRUCT	5

/* struct / union definitions */
struct member {
	struct member *next;
	struct name *nm;
	u8 type;
	u16 off;
};

struct strct {
	struct member *first;
	u16 size;
	u8 defined;
};

/*
 *	Operands. The expression parser returns one of these; the value is
 *	only turned into code when it is needed.
 */
struct opd {
	u8 k;		/* O_xxx */
	u8 type;
	s16 v;		/* constant, offset */
	u16 sym;	/* object symbol or segment */
};

/*
 *	Globals
 */
extern u8 tok;			/* current token */
extern u16 tokval;		/* T_NUM value */
extern struct name *tokname;	/* T_ID */
extern char strbuf[];		/* T_STR text */
extern u16 strlen_;		/* T_STR length */
extern u16 line;
extern u8 errors;

extern struct type types[];
extern u8 ntypes;
extern struct strct structs[];
extern u8 nstructs;

extern u16 datapos;		/* data segment offset */
extern u16 bsspos;		/* bss segment offset */
extern u16 litpos;		/* literal segment offset */

/* lex.c */
void lexinit(int fd, int nfd);
void next(void);
void unput(u8 t);
u8 accept(u8 t);
void expect(u8 t);
void error(const char *m);
void errorn(const char *m, struct name *n);
void fatal(const char *m);
struct name *idp(u16 id);
const char *idname(struct name *n);
#define tokid()	tokname
void *alloc(u16 n);
void putstr(int fd, const char *s);
void putnum(int fd, u16 n);

/* type.c */
u8 mktype(u8 kind, u8 sub, u16 size);
u8 isptr(u8 t);
u8 isint(u8 t);
u8 issigned(u8 t);
u8 ischar(u8 t);
u16 tsize(u8 t);
u16 elsize(u8 t);
u8 deref(u8 t);
u8 decay(u8 t);
u8 is_typename(void);
u8 basetype(u8 *cls);
u8 declarator(u8 t, struct name **np, u8 abstract);
u8 typename(void);
void declaration(u8 local);
struct member *findmember(u8 t, struct name *n);

/* expr.c */
void expr(struct opd *o);
void assign(struct opd *o);
void condexpr(struct opd *o);
u16 constexpr(void);
void rvalue(struct opd *o);
void tohl(struct opd *o);
void tobool(struct opd *o, u8 jumpif, u16 label);
void cast(struct opd *o, u8 t);

/* stmt.c */
void funcbody(struct name *n, u8 type);
void initlocal(u16 off, u8 type);
u8 initglobal(u8 type);

/* parameters of the last parameter list */
struct param {
	u16 id;		/* NOID if none */
	u8 type;
};
#define NOID 0xFFFF
extern struct param params[];
extern u8 nparams;

/* local symbols */
struct local {
	struct name *nm;
	u8 cls;		/* C_LOCAL, C_STATIC, C_TYPEDEF, C_GLOBAL (extern) */
	u8 type;
	u8 flags;
	u16 val;
};
extern struct local locals[];
extern u8 nlocals;
extern u8 scopebase;
extern s16 frameoff;		/* lowest frame offset in use */
extern u8 functype;		/* type of the function being compiled */
extern u8 infunc;
struct local *findlocal(struct name *n);
struct local *addlocal(struct name *n, u8 cls, u8 type);

/* ir.c */
extern u8 nocode;
void irop(u8 op);
void irb(u8 b);
void irw(u16 w);
void iropd(u8 op, struct opd *o, u8 cls);
void gb(u8 b);
void g2(u8 a, u8 b);
void g3(u8 a, u8 b, u8 c);
void gw(u16 w);
void gld_hl(u16 v);
void gld_de(u16 v);
void gix(u8 op, s16 off);
void gjp(u8 op, u16 label);
void gcall(u8 helper);
void gcallsym(u16 sym);
void glabword(u16 l);
void gaddsp(s16 n);
void gscale(u16 n);
void gfar(s16 off);
u16 newlabel(void);
void setlabel(u16 l);
void funcbegin(u16 sym);
void funcend(u16 frame);
u16 symref(struct name *n);
void helpers(void);


void outinit(const char *name);
void outfinish(void);
void dbyte(u8 b);
void dword(u16 w);
void drel(u8 seg, u16 off);
void dsym(u16 sym, u16 off);
void lbyte(u8 b);
u16 newsym(struct name *n, const char *s);
void defsym(u16 sym, u8 seg, u16 off, u8 pub);
