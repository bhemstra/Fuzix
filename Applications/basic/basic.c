/*
 *	Fuzix BASIC
 *
 *	An integer BASIC in the spirit of ECMA-55 and TRS-80 Level II BASIC.
 *
 *	Numbers are 16 bit integers (-32768 to 32767). Strings are up to 255
 *	characters. Variable names are a letter followed by letters and
 *	digits, of which the first two count (as on the TRS-80), with $ for
 *	strings. Arrays are made with DIM or get 11 elements (0-10) when
 *	first used. True is -1, false 0.
 *
 *	The program is kept tokenized: keywords become one byte (0x80 and
 *	up) when a line is entered and are spelt out again by LIST.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include <setjmp.h>
#include <unistd.h>
#include <signal.h>
#include "basic.h"

/*
 *	Keywords. The order matters: the token is 0x80 + the index, and
 *	longer words that start with a shorter one must come first.
 */
static const char *keywords[] = {
	"PRINT", "INPUT", "IF", "THEN", "ELSE", "FOR", "TO", "STEP", "NEXT",
	"GOTO", "GOSUB", "RETURN", "LET", "REM", "CLEAR", "LIST", "RUN",
	"STOP", "END", "DIM", "RANDOMIZE", "READ", "DATA", "RESTORE", "ON",
	"CLS", "SAVE", "LOAD", "NEW", "AND", "OR", "NOT", "MOD", "TAB(",
	"ABS(", "SGN(", "INT(", "RND(", "LEN(", "VAL(", "ASC(", "CHR$(",
	"STR$(", "LEFT$(", "RIGHT$(", "MID$(", "BYE", "SYSTEM", "CONT",
	"POS(", "SPC(", "FRE(", "INSTR(", "STRING$(", "TRON", "TROFF",
	NULL
};

#define TK_PRINT	0x80
#define TK_INPUT	0x81
#define TK_IF	0x82
#define TK_THEN	0x83
#define TK_ELSE	0x84
#define TK_FOR	0x85
#define TK_TO	0x86
#define TK_STEP	0x87
#define TK_NEXT	0x88
#define TK_GOTO	0x89
#define TK_GOSUB	0x8A
#define TK_RETURN	0x8B
#define TK_LET	0x8C
#define TK_REM	0x8D
#define TK_CLEAR	0x8E
#define TK_LIST	0x8F
#define TK_RUN	0x90
#define TK_STOP	0x91
#define TK_END	0x92
#define TK_DIM	0x93
#define TK_RANDOMIZE	0x94
#define TK_READ	0x95
#define TK_DATA	0x96
#define TK_RESTORE	0x97
#define TK_ON	0x98
#define TK_CLS	0x99
#define TK_SAVE	0x9A
#define TK_LOAD	0x9B
#define TK_NEW	0x9C
#define TK_AND	0x9D
#define TK_OR	0x9E
#define TK_NOT	0x9F
#define TK_MOD	0xA0
#define TK_TAB	0xA1
#define TK_ABS	0xA2
#define TK_SGN	0xA3
#define TK_INT	0xA4
#define TK_RND	0xA5
#define TK_LEN	0xA6
#define TK_VAL	0xA7
#define TK_ASC	0xA8
#define TK_CHR	0xA9
#define TK_STR	0xAA
#define TK_LEFT	0xAB
#define TK_RIGHT	0xAC
#define TK_MID	0xAD
#define TK_BYE	0xAE
#define TK_SYSTEM	0xAF
#define TK_CONT	0xB0
#define TK_POS	0xB1
#define TK_SPC	0xB2
#define TK_FRE	0xB3
#define TK_INSTR	0xB4
#define TK_STRING	0xB5
#define TK_TRON	0xB6
#define TK_TROFF	0xB7
/* two character operators */
#define TK_LE	0xF0
#define TK_GE	0xF1
#define TK_NE	0xF2


static const char *errmsg[] = {
	"", "Syntax error", "Division by zero", "Out of memory",
	"RETURN without GOSUB", "Type mismatch", "Overflow",
	"Subscript out of range", "Undefined line", "NEXT without FOR",
	"Out of DATA", "String too long", "Illegal function call",
	"Can't continue", "Redimensioned array", "Break", "File error"
};

/*
 *	Program store: lines in order, each
 *	line number (2), length of the whole line (1), tokens, 0
 */
static unsigned char *prog;		/* start of the program */
static unsigned char *progend;		/* first free byte */
static unsigned char *memend;		/* end of the program space */
static unsigned memsize;

/* Execution state */
static unsigned char *ip;		/* interpreter pointer */
static unsigned char *curline;		/* line being run, NULL: direct */
static unsigned char *contline;		/* where CONT goes on */
static unsigned char *contip;
static unsigned char *dataptr;		/* next DATA item, NULL: start */
static unsigned char *dataline;
static unsigned char running;
static unsigned char trace;
static unsigned char jumped;		/* ip is at the start of a statement */
static jmp_buf onerror;
static volatile unsigned char stopkey;
static int column;			/* print position */

/*
 *	Variables: a linked list. Scalars hold the value; arrays hold their
 *	dimensions and the elements (ints or string pointers).
 */
struct var {
	struct var *next;
	char name[2];
	unsigned char str;		/* string variable */
	unsigned char dims;		/* 0: scalar */
	unsigned dim[2];		/* upper bounds */
	union {
		int i;
		char *s;
		int *ia;
		char **sa;
	} v;
};

static struct var *vars;

/* GOSUB and FOR stack */
struct frame {
	unsigned char type;		/* 'G' gosub, 'F' for */
	unsigned char *line;		/* the line to go back to */
	unsigned char *ip;		/* and the place in it */
	int *var;			/* FOR: the loop variable */
	int limit, step;
};

#define NFRAME 24
static struct frame stack[NFRAME];
static unsigned char sp;

/* A number as text (printf is too large for a 32K machine) */
static char *numstr(long v)
{
	static char b[12];
	char *p = b + 11;
	unsigned long u = v < 0 ? -v : v;
	*p = 0;
	do {
		*--p = '0' + u % 10;
		u /= 10;
	} while (u);
	if (v < 0)
		*--p = '-';
	return p;
}

static void error(unsigned char n)
{
	if (column)
		putchar('\n');
	column = 0;
	fputs("?", stdout);
	fputs(errmsg[n], stdout);
	if (curline) {
		fputs(" in ", stdout);
		fputs(numstr(*(unsigned short *)curline), stdout);
	}
	putchar('\n');
	contline = NULL;
	longjmp(onerror, 1);
}

static void *xmalloc(unsigned n)
{
	void *p = malloc(n ? n : 1);
	if (!p)
		error(ERR_MEMORY);
	return p;
}

/*
 *	Values
 */
struct value {
	unsigned char str;
	int i;
	char *s;		/* strings: malloc'd, owned by the value */
};

static void freeval(struct value *v)
{
	if (v->str && v->s)
		free(v->s);
	v->s = NULL;
}

static char *strdup2(const char *s)
{
	char *p = xmalloc(strlen(s) + 1);
	strcpy(p, s);
	return p;
}

/*
 *	The tokenizer: turn a typed line into tokens
 */
static unsigned char tokbuf[256];

/*
 *	Keywords are whole words, so a variable may start with one (TOTAL is
 *	not TO TAL). Function keywords include the $ and ( that follow.
 */
static unsigned char kwmatch(const char *p, unsigned char *len)
{
	char w[12];
	unsigned char i, n = 0;
	while (isalnum(p[n]) && n < 10) {
		w[n] = toupper(p[n]);
		n++;
	}
	if (isalnum(p[n]))
		return 0;
	if (p[n] == '$')
		w[n++] = '$';
	if (p[n] == '(')
		w[n++] = '(';
	w[n] = 0;
	for (;;) {
		for (i = 0; keywords[i]; i++)
			if (strcmp(w, keywords[i]) == 0) {
				*len = n;
				return 0x80 + i;
			}
		/* try again without the ( and then without the $ */
		if (n && (w[n - 1] == '(' || w[n - 1] == '$'))
			w[--n] = 0;
		else
			return 0;
	}
}

static unsigned tokenize(const char *p)
{
	unsigned char *o = tokbuf;
	unsigned char t, n;
	unsigned char rem = 0;

	while (*p && *p != '\n') {
		if (o > tokbuf + sizeof(tokbuf) - 4)
			error(ERR_LONG);
		if (rem) {
			*o++ = *p++;
			continue;
		}
		if (*p == '"') {
			*o++ = *p++;
			while (*p && *p != '"' && *p != '\n')
				*o++ = *p++;
			if (*p == '"')
				*o++ = *p++;
			continue;
		}
		if (*p == ' ') {
			p++;
			continue;
		}
		if (*p == '\'') {
			*o++ = TK_REM;
			p++;
			rem = 1;
			continue;
		}
		if (p[0] == '<' && p[1] == '=') {
			*o++ = TK_LE;
			p += 2;
			continue;
		}
		if (p[0] == '>' && p[1] == '=') {
			*o++ = TK_GE;
			p += 2;
			continue;
		}
		if (p[0] == '<' && p[1] == '>') {
			*o++ = TK_NE;
			p += 2;
			continue;
		}
		if (isalpha(*p)) {
			t = kwmatch(p, &n);
			if (t) {
				*o++ = t;
				p += n;
				if (t == TK_REM || t == TK_DATA)
					rem = t == TK_REM;
				if (t == TK_DATA) {
					/* keep DATA as typed */
					while (*p == ' ')
						p++;
					while (*p && *p != '\n' && *p != ':')
						*o++ = *p++;
				}
				continue;
			}
			/* a variable name: all of it in upper case */
			while (isalnum(*p))
				*o++ = toupper(*p++);
			continue;
		}
		*o++ = *p++;
	}
	*o++ = 0;
	return o - tokbuf;
}

/*
 *	Program lines
 */
#define LNUM(l)		(*(unsigned short *)(l))
#define LLEN(l)		((l)[2])
#define LTEXT(l)	((l) + 3)
#define LNEXT(l)	((l) + LLEN(l))

static unsigned char *findline(unsigned n)
{
	unsigned char *l = prog;
	while (l < progend && LNUM(l) < n)
		l = LNEXT(l);
	return l;
}

static void clearvars(void);

static void storeline(unsigned n, unsigned char *t, unsigned len)
{
	unsigned char *l = findline(n);
	unsigned size = len + 3;

	clearvars();
	contline = NULL;
	if (l < progend && LNUM(l) == n) {
		unsigned old = LLEN(l);
		memmove(l, l + old, progend - (l + old));
		progend -= old;
	}
	if (len <= 1)		/* an empty line deletes */
		return;
	if (size > 255)
		error(ERR_LONG);
	if (progend + size > memend)
		error(ERR_MEMORY);
	memmove(l + size, l, progend - l);
	LNUM(l) = n;
	LLEN(l) = size;
	memcpy(LTEXT(l), t, len);
	progend += size;
}

static void listline(FILE *f, unsigned char *l)
{
	unsigned char *p = LTEXT(l);
	unsigned char c, last = ' ';
	fputs(numstr(LNUM(l)), f);
	fputc(' ', f);
	while ((c = *p++) != 0) {
		if (c == '"') {
			fputc(c, f);
			while (*p && *p != '"')
				fputc(*p++, f);
			if (*p)
				fputc(*p++, f);
		} else if (c == TK_LE)
			fputs("<=", f);
		else if (c == TK_GE)
			fputs(">=", f);
		else if (c == TK_NE)
			fputs("<>", f);
		else if (c >= 0x80 && c < 0x80 + TK_TROFF - TK_PRINT + 1) {
			const char *k = keywords[c - 0x80];
			if (isalnum(last) || last == '"' || last == '$')
				fputc(' ', f);
			fputs(k, f);
			c = k[strlen(k) - 1];
			if (c != '(' && (isalnum(*p) || *p == '"'))
				fputc(' ', f);
		} else
			fputc(c, f);
		last = c;
	}
	fputc('\n', f);
}

/*
 *	Variables
 */
static void clearvars(void)
{
	struct var *v;
	unsigned i, n;
	while (vars) {
		v = vars;
		vars = v->next;
		if (v->str) {
			if (v->dims) {
				n = (v->dim[0] + 1) * (v->dims == 2 ? v->dim[1] + 1 : 1);
				for (i = 0; i < n; i++)
					if (v->v.sa[i])
						free(v->v.sa[i]);
				free(v->v.sa);
			} else if (v->v.s)
				free(v->v.s);
		} else if (v->dims)
			free(v->v.ia);
		free(v);
	}
	sp = 0;
	dataptr = NULL;
}

static void skipsp(void)
{
	while (*ip == ' ')
		ip++;
}

/* Read a variable name at ip */
static void varname(char *n, unsigned char *str)
{
	if (!isupper(*ip))
		error(ERR_SYNTAX);
	n[0] = *ip++;
	n[1] = 0;
	if (isalnum(*ip))
		n[1] = *ip++;
	while (isalnum(*ip))
		ip++;
	*str = 0;
	if (*ip == '$') {
		*str = 1;
		ip++;
	}
}

static struct var *findvar(const char *n, unsigned char str, unsigned char arr)
{
	struct var *v;
	for (v = vars; v; v = v->next)
		if (v->name[0] == n[0] && v->name[1] == n[1] && v->str == str &&
		    (v->dims != 0) == arr)
			return v;
	return NULL;
}

static struct var *newvar(const char *n, unsigned char str)
{
	struct var *v = xmalloc(sizeof(struct var));
	memset(v, 0, sizeof(struct var));
	v->name[0] = n[0];
	v->name[1] = n[1];
	v->str = str;
	v->next = vars;
	vars = v;
	return v;
}

static void dimension(struct var *v, unsigned char dims, unsigned *d)
{
	unsigned long n = d[0] + 1;
	if (dims == 2)
		n *= d[1] + 1;
	if (n > 8000)
		error(ERR_MEMORY);
	v->dims = dims;
	v->dim[0] = d[0];
	v->dim[1] = dims == 2 ? d[1] : 0;
	if (v->str) {
		v->v.sa = xmalloc(n * sizeof(char *));
		memset(v->v.sa, 0, n * sizeof(char *));
	} else {
		v->v.ia = xmalloc(n * sizeof(int));
		memset(v->v.ia, 0, n * sizeof(int));
	}
}

static void expr(struct value *r);
static int intexpr(void);

/*
 *	Find the storage of the variable at ip. Returns a pointer to the int
 *	or to the string pointer.
 */
static void *lvalue(unsigned char *str)
{
	char n[2];
	struct var *v;
	unsigned d[2], i;
	unsigned char nd = 0;

	varname(n, str);
	if (*ip == '(') {
		ip++;
		d[nd++] = intexpr();
		if (*ip == ',') {
			ip++;
			d[nd++] = intexpr();
		}
		if (*ip++ != ')')
			error(ERR_SYNTAX);
		v = findvar(n, *str, 1);
		if (!v) {
			unsigned ten[2];
			ten[0] = ten[1] = 10;
			v = newvar(n, *str);
			dimension(v, nd, ten);
		}
		if (nd != v->dims || d[0] > v->dim[0] || (nd == 2 && d[1] > v->dim[1]))
			error(ERR_RANGE);
		i = d[0];
		if (nd == 2)
			i = i * (v->dim[1] + 1) + d[1];
		if (*str)
			return v->v.sa + i;
		return v->v.ia + i;
	}
	v = findvar(n, *str, 0);
	if (!v)
		v = newvar(n, *str);
	if (*str)
		return &v->v.s;
	return &v->v.i;
}

/*
 *	Expressions
 *
 *	or: and [OR and]
 *	and: not [AND not]
 *	not: [NOT] compare
 *	compare: sum [op sum]
 *	sum: term [+- term]
 *	term: unary [* / MOD unary]
 *	unary: [-+] primary
 */
static void needint(struct value *v)
{
	if (v->str)
		error(ERR_TYPE);
}

static void needstr(struct value *v)
{
	if (!v->str)
		error(ERR_TYPE);
}

static void expect(unsigned char c)
{
	if (*ip++ != c)
		error(ERR_SYNTAX);
}

static void strval(struct value *v, const char *s)
{
	v->str = 1;
	v->s = strdup2(s);
}

static void strexpr(struct value *v)
{
	expr(v);
	needstr(v);
}

static unsigned rnd(unsigned n)
{
	if (n == 0)
		return rand();
	return rand() % n + 1;
}

/* Functions: the token has been read (with its "(") */
static void function(unsigned char f, struct value *r)
{
	struct value a;
	int n, m;
	char *s;

	r->str = 0;
	r->s = NULL;
	switch (f) {
	case TK_ABS:
	case TK_SGN:
	case TK_INT:
	case TK_RND:
	case TK_CHR:
	case TK_STR:
	case TK_FRE:
	case TK_POS:
		n = intexpr();
		if (f == TK_ABS)
			r->i = n < 0 ? -n : n;
		else if (f == TK_SGN)
			r->i = n < 0 ? -1 : n > 0;
		else if (f == TK_INT)
			r->i = n;
		else if (f == TK_RND)
			r->i = rnd(n);
		else if (f == TK_FRE)
			r->i = memend - progend;
		else if (f == TK_POS)
			r->i = column;
		else if (f == TK_CHR) {
			char b[2];
			b[0] = n;
			b[1] = 0;
			strval(r, b);
		} else {
			strval(r, numstr(n));
		}
		break;
	case TK_LEN:
	case TK_VAL:
	case TK_ASC:
		strexpr(&a);
		if (f == TK_LEN)
			r->i = strlen(a.s);
		else if (f == TK_VAL)
			r->i = atoi(a.s);
		else {
			if (!*a.s)
				error(ERR_FUNC);
			r->i = (unsigned char)*a.s;
		}
		freeval(&a);
		break;
	case TK_LEFT:
	case TK_RIGHT:
	case TK_MID:
		strexpr(&a);
		expect(',');
		n = intexpr();
		m = 255;
		if (f == TK_MID && *ip == ',') {
			ip++;
			m = intexpr();
		}
		if (n < 0 || m < 0 || (f == TK_MID && n < 1))
			error(ERR_FUNC);
		s = a.s;
		if (f == TK_LEFT) {
			if (n < (int)strlen(s))
				s[n] = 0;
		} else if (f == TK_RIGHT) {
			if (n < (int)strlen(s))
				s += strlen(s) - n;
		} else {
			if (n - 1 > (int)strlen(s))
				n = strlen(s) + 1;
			s += n - 1;
			if (m < (int)strlen(s))
				s[m] = 0;
		}
		strval(r, s);
		freeval(&a);
		break;
	case TK_INSTR:
		{
			struct value b;
			char *p;
			strexpr(&a);
			expect(',');
			strexpr(&b);
			p = strstr(a.s, b.s);
			r->i = p ? p - a.s + 1 : 0;
			freeval(&a);
			freeval(&b);
		}
		break;
	case TK_STRING:
		n = intexpr();
		expect(',');
		expr(&a);
		m = a.str ? (unsigned char)*a.s : a.i;
		freeval(&a);
		if (n < 0 || n > 255)
			error(ERR_FUNC);
		s = xmalloc(n + 1);
		memset(s, m, n);
		s[n] = 0;
		r->str = 1;
		r->s = s;
		break;
	default:
		error(ERR_SYNTAX);
	}
	expect(')');
}

static void primary(struct value *r)
{
	unsigned char c = *ip;
	unsigned char str;
	void *p;

	r->str = 0;
	r->s = NULL;
	if (isdigit(c)) {
		long v = 0;
		while (isdigit(*ip)) {
			v = v * 10 + *ip++ - '0';
			if (v > 32768L)
				error(ERR_OVERFLOW);
		}
		r->i = v;
		return;
	}
	if (c == '&' && (ip[1] == 'H' || ip[1] == 'h')) {
		unsigned v = 0;
		ip += 2;
		while (isxdigit(*ip)) {
			v = v * 16 + (isdigit(*ip) ? *ip - '0' : toupper(*ip) - 'A' + 10);
			ip++;
		}
		r->i = v;
		return;
	}
	if (c == '"') {
		unsigned char *e;
		char *s;
		ip++;
		e = ip;
		while (*e && *e != '"')
			e++;
		s = xmalloc(e - ip + 1);
		memcpy(s, ip, e - ip);
		s[e - ip] = 0;
		ip = *e ? e + 1 : e;
		r->str = 1;
		r->s = s;
		return;
	}
	if (c == '(') {
		ip++;
		expr(r);
		expect(')');
		return;
	}
	if (c >= TK_ABS && c <= TK_STRING && c != TK_BYE && c != TK_SYSTEM && c != TK_CONT && c != TK_SPC) {
		ip++;
		function(c, r);
		return;
	}
	if (isupper(c)) {
		p = lvalue(&str);
		if (str) {
			r->str = 1;
			r->s = strdup2(*(char **)p ? *(char **)p : "");
		} else
			r->i = *(int *)p;
		return;
	}
	error(ERR_SYNTAX);
}

static void unary(struct value *r)
{
	if (*ip == '-') {
		ip++;
		unary(r);
		needint(r);
		r->i = -r->i;
		return;
	}
	if (*ip == '+') {
		ip++;
		unary(r);
		return;
	}
	primary(r);
}

static void term(struct value *r)
{
	struct value b;
	unsigned char op;
	unary(r);
	while (*ip == '*' || *ip == '/' || *ip == TK_MOD) {
		op = *ip++;
		needint(r);
		unary(&b);
		needint(&b);
		if (op == '*') {
			long v = (long)r->i * b.i;
			if (v > 32767L || v < -32768L)
				error(ERR_OVERFLOW);
			r->i = v;
		} else {
			if (b.i == 0)
				error(ERR_DIVZERO);
			r->i = op == '/' ? r->i / b.i : r->i % b.i;
		}
	}
}

static void sum(struct value *r)
{
	struct value b;
	unsigned char op;
	term(r);
	while (*ip == '+' || *ip == '-') {
		op = *ip++;
		term(&b);
		if (r->str || b.str) {
			char *s;
			if (op != '+' || !r->str || !b.str)
				error(ERR_TYPE);
			if (strlen(r->s) + strlen(b.s) > 255)
				error(ERR_LONG);
			s = xmalloc(strlen(r->s) + strlen(b.s) + 1);
			strcpy(s, r->s);
			strcat(s, b.s);
			freeval(r);
			freeval(&b);
			r->s = s;
			continue;
		}
		{
			long v = op == '+' ? (long)r->i + b.i : (long)r->i - b.i;
			if (v > 32767L || v < -32768L)
				error(ERR_OVERFLOW);
			r->i = v;
		}
	}
}

static void compare(struct value *r)
{
	struct value b;
	unsigned char op;
	int c;
	sum(r);
	while (*ip == '=' || *ip == '<' || *ip == '>' || *ip == TK_LE ||
	       *ip == TK_GE || *ip == TK_NE) {
		op = *ip++;
		sum(&b);
		if (r->str != b.str)
			error(ERR_TYPE);
		if (r->str) {
			c = strcmp(r->s, b.s);
			freeval(r);
			freeval(&b);
			r->str = 0;
		} else
			c = r->i < b.i ? -1 : r->i > b.i;
		switch (op) {
		case '=': c = c == 0; break;
		case '<': c = c < 0; break;
		case '>': c = c > 0; break;
		case TK_LE: c = c <= 0; break;
		case TK_GE: c = c >= 0; break;
		default: c = c != 0; break;
		}
		r->i = c ? -1 : 0;
	}
}

static void notexpr(struct value *r)
{
	if (*ip == TK_NOT) {
		ip++;
		notexpr(r);
		needint(r);
		r->i = ~r->i;
		return;
	}
	compare(r);
}

static void andexpr(struct value *r)
{
	struct value b;
	notexpr(r);
	while (*ip == TK_AND) {
		ip++;
		needint(r);
		notexpr(&b);
		needint(&b);
		r->i &= b.i;
	}
}

static void expr(struct value *r)
{
	struct value b;
	andexpr(r);
	while (*ip == TK_OR) {
		ip++;
		needint(r);
		andexpr(&b);
		needint(&b);
		r->i |= b.i;
	}
}

static int intexpr(void)
{
	struct value v;
	expr(&v);
	needint(&v);
	return v.i;
}

/*
 *	Statements
 */
static unsigned char endstmt(void)
{
	return *ip == 0 || *ip == ':' || *ip == TK_ELSE;
}

static void outch(char c)
{
	putchar(c);
	if (c == '\n')
		column = 0;
	else if (c == '\b') {
		if (column)
			column--;
	} else
		column++;
}

static void outstr(const char *s)
{
	while (*s)
		outch(*s++);
}

static void tab(int n)
{
	while (column < n)
		outch(' ');
}

static void print(FILE *f)
{
	struct value v;
	unsigned char nl = 1;
	char b[12];

	while (!endstmt()) {
		nl = 1;
		if (*ip == ';') {
			ip++;
			nl = 0;
			continue;
		}
		if (*ip == ',') {
			ip++;
			if (f == stdout)
				tab((column / 16 + 1) * 16);
			else
				fputc(',', f);
			nl = 0;
			continue;
		}
		if (*ip == TK_TAB || *ip == TK_SPC) {
			unsigned char t = *ip++;
			int n = intexpr();
			expect(')');
			if (t == TK_TAB)
				tab(n);
			else
				while (n-- > 0)
					outch(' ');
			nl = 0;
			continue;
		}
		expr(&v);
		if (v.str) {
			if (f == stdout)
				outstr(v.s);
			else
			{
				fputc('"', f);
				fputs(v.s, f);
				fputc('"', f);
			}
			freeval(&v);
		} else {
			b[0] = ' ';
			strcpy(b + 1, numstr(v.i));
			strcat(b, " ");
			if (f == stdout)
				outstr(v.i < 0 ? b + 1 : b);
			else
				fputs(numstr(v.i), f);
		}
	}
	if (nl) {
		if (f == stdout)
			outch('\n');
		else
			fputc('\n', f);
	}
}

/* Assign a string or number from text (INPUT, READ) */
static unsigned char *assigntext(unsigned char *t, unsigned char data)
{
	unsigned char str;
	void *p = lvalue(&str);
	char buf[256];
	char *o = buf;
	unsigned char q = 0;

	while (*t == ' ')
		t++;
	if (*t == '"') {
		q = 1;
		t++;
	}
	while (*t && (q ? *t != '"' : (*t != ',' && *t != ':')) && o < buf + 255)
		*o++ = *t++;
	if (q && *t == '"')
		t++;
	*o = 0;
	if (!q)
		while (o > buf && o[-1] == ' ')
			*--o = 0;
	if (str) {
		char **s = p;
		if (*s)
			free(*s);
		*s = strdup2(buf);
	} else {
		char *e;
		long v = strtol(buf, &e, 10);
		while (*e == ' ')
			e++;
		if (*e || !*buf) {
			if (data)
				error(ERR_TYPE);
			return NULL;
		}
		*(int *)p = v;
	}
	return t;
}

static void input(void)
{
	char line[256];
	unsigned char *t, *save;

	if (*ip == '"') {
		struct value v;
		primary(&v);
		outstr(v.s);
		freeval(&v);
		if (*ip == ';' || *ip == ',')
			ip++;
	}
again:
	outstr("? ");
	fflush(stdout);
	if (!fgets(line, sizeof(line), stdin))
		exit(0);
	column = 0;
	t = (unsigned char *)line;
	save = ip;
	for (;;) {
		char *nl = strchr((char *)t, '\n');
		if (nl)
			*nl = 0;
		t = assigntext(t, 0);
		if (!t) {
			outstr("?Redo from start\n");
			ip = save;
			goto again;
		}
		if (*ip != ',')
			break;
		ip++;
		if (*t == ',')
			t++;
		else {
			/* more needed */
			outstr("?? ");
			fflush(stdout);
			if (!fgets(line, sizeof(line), stdin))
				exit(0);
			t = (unsigned char *)line;
		}
	}
}

/* Move to the next DATA item */
static void nextdata(void)
{
	unsigned char *p;
	if (dataptr && *dataptr == ',') {
		dataptr++;
		return;
	}
	if (!dataptr) {
		dataline = prog;
		dataptr = prog < progend ? LTEXT(prog) : NULL;
	}
	/* Look for the next DATA statement */
	while (dataptr) {
		p = dataptr;
		while (*p && *p != TK_DATA) {
			if (*p == '"') {
				p++;
				while (*p && *p != '"')
					p++;
				if (*p)
					p++;
				continue;
			}
			if (*p == TK_REM)
				while (*p)
					p++;
			else
				p++;
		}
		if (*p) {
			dataptr = p + 1;
			return;
		}
		dataline = LNEXT(dataline);
		dataptr = dataline < progend ? LTEXT(dataline) : NULL;
	}
	error(ERR_DATA);
}

static void readstmt(void)
{
	for (;;) {
		nextdata();
		dataptr = assigntext(dataptr, 1);
		if (*ip != ',')
			break;
		ip++;
	}
}

static unsigned linenum(void)
{
	long v = 0;
	skipsp();
	if (!isdigit(*ip))
		error(ERR_SYNTAX);
	while (isdigit(*ip)) {
		v = v * 10 + *ip++ - '0';
		if (v > 65529L)
			error(ERR_SYNTAX);
	}
	return v;
}

static void jump(unsigned n)
{
	unsigned char *l = findline(n);
	if (l >= progend || LNUM(l) != n)
		error(ERR_LINE);
	curline = l;
	ip = LTEXT(l);
	running = 1;
	jumped = 1;
}

static void push(unsigned char type)
{
	if (sp == NFRAME)
		error(ERR_MEMORY);
	stack[sp].type = type;
	stack[sp].line = curline;
	stack[sp].ip = ip;
	sp++;
}

static void forstmt(void)
{
	unsigned char str;
	int *v;
	int limit, step = 1;
	unsigned char i;

	v = lvalue(&str);
	if (str)
		error(ERR_TYPE);
	expect('=');
	*v = intexpr();
	expect(TK_TO);
	limit = intexpr();
	if (*ip == TK_STEP) {
		ip++;
		step = intexpr();
	}
	/* A FOR on the same variable replaces the old loop */
	for (i = 0; i < sp; i++)
		if (stack[i].type == 'F' && stack[i].var == v) {
			sp = i;
			break;
		}
	push('F');
	stack[sp - 1].var = v;
	stack[sp - 1].limit = limit;
	stack[sp - 1].step = step;
}

static void nextstmt(void)
{
	struct frame *f;
	int *v = NULL;
	unsigned char str;
	long n;

	if (!endstmt()) {
		v = lvalue(&str);
		if (str)
			error(ERR_TYPE);
	}
	for (;;) {
		while (sp && stack[sp - 1].type != 'F')
			sp--;
		if (!sp)
			error(ERR_NEXT);
		f = stack + sp - 1;
		if (!v || f->var == v)
			break;
		sp--;
	}
	n = (long)*f->var + f->step;
	if ((f->step >= 0 && n > f->limit) || (f->step < 0 && n < f->limit)) {
		sp--;
		/* NEXT I,J */
		if (*ip == ',') {
			ip++;
			nextstmt();
		}
		return;
	}
	*f->var = n;
	curline = f->line;
	ip = f->ip;
}

static void dimstmt(void)
{
	char n[2];
	unsigned char str, nd;
	unsigned d[2];
	struct var *v;
	for (;;) {
		varname(n, &str);
		expect('(');
		nd = 0;
		d[nd++] = intexpr();
		if (*ip == ',') {
			ip++;
			d[nd++] = intexpr();
		}
		expect(')');
		if (findvar(n, str, 1))
			error(ERR_REDIM);
		v = newvar(n, str);
		dimension(v, nd, d);
		if (*ip != ',')
			break;
		ip++;
	}
}

static void let(void)
{
	unsigned char str;
	void *p = lvalue(&str);
	struct value v;
	expect('=');
	expr(&v);
	if (v.str != str)
		error(ERR_TYPE);
	if (str) {
		char **s = p;
		if (*s)
			free(*s);
		*s = v.s;
	} else
		*(int *)p = v.i;
}

static void list(void)
{
	unsigned lo = 0, hi = 65535;
	unsigned char *l;
	if (isdigit(*ip))
		lo = hi = linenum();
	if (*ip == '-') {
		ip++;
		hi = isdigit(*ip) ? linenum() : 65535;
	}
	for (l = findline(lo); l < progend && LNUM(l) <= hi; l = LNEXT(l)) {
		if (stopkey)
			break;
		listline(stdout, l);
	}
}

static char *filename(char *b)
{
	struct value v;
	strexpr(&v);
	strncpy(b, v.s, 60);
	b[60] = 0;
	freeval(&v);
	if (!strchr(b, '.'))
		strcat(b, ".bas");
	return b;
}

static void save(void)
{
	char n[66];
	FILE *f = fopen(filename(n), "w");
	unsigned char *l;
	if (!f)
		error(ERR_FILE);
	for (l = prog; l < progend; l = LNEXT(l))
		listline(f, l);
	fclose(f);
}

static void enter(char *line);

static void load(void)
{
	char n[66], line[256];
	FILE *f = fopen(filename(n), "r");
	if (!f)
		error(ERR_FILE);
	progend = prog;
	clearvars();
	while (fgets(line, sizeof(line), f))
		if (isdigit(*line))
			enter(line);
	fclose(f);
	curline = NULL;
	running = 0;
}

static void run(void)
{
	clearvars();
	srand(1);
	if (isdigit(*ip)) {
		jump(linenum());
		return;
	}
	if (prog == progend) {
		running = 0;
		return;
	}
	curline = prog;
	ip = LTEXT(prog);
	running = 1;
	jumped = 1;
}

static void statement(void);

static void ifstmt(void)
{
	int c = intexpr();
	if (*ip == TK_GOTO) {
		/* IF x GOTO n */
	} else
		expect(TK_THEN);
	if (c) {
		if (*ip == TK_GOTO)
			ip++;
		if (isdigit(*ip))
			jump(linenum());
		else
			statement();
		return;
	}
	/* Find the ELSE that belongs to us, or skip the line */
	{
		unsigned char depth = 0;
		while (*ip) {
			if (*ip == '"') {
				ip++;
				while (*ip && *ip != '"')
					ip++;
				if (*ip)
					ip++;
				continue;
			}
			if (*ip == TK_IF)
				depth++;
			if (*ip == TK_ELSE) {
				if (!depth) {
					ip++;
					if (isdigit(*ip))
						jump(linenum());
					else
						statement();
					return;
				}
				depth--;
			}
			ip++;
		}
	}
}

static void onstmt(void)
{
	int n = intexpr();
	unsigned char t = *ip++;
	unsigned target = 0;
	if (t != TK_GOTO && t != TK_GOSUB)
		error(ERR_SYNTAX);
	for (;;) {
		unsigned v = linenum();
		if (--n == 0)
			target = v;
		if (*ip != ',')
			break;
		ip++;
	}
	if (!target)
		return;		/* out of range: go on */
	if (t == TK_GOSUB) {
		/* return to after the whole ON statement */
		push('G');
	}
	jump(target);
}

static void statement(void)
{
	unsigned char c;
	skipsp();
	c = *ip;
	if (c == 0 || c == ':')
		return;
	if (c < 0x80) {
		if (c == '?') {
			ip++;
			print(stdout);
			return;
		}
		let();
		return;
	}
	ip++;
	switch (c) {
	case TK_PRINT:
		print(stdout);
		break;
	case TK_INPUT:
		input();
		break;
	case TK_IF:
		ifstmt();
		break;
	case TK_FOR:
		forstmt();
		break;
	case TK_NEXT:
		nextstmt();
		break;
	case TK_GOTO:
		jump(linenum());
		break;
	case TK_GOSUB:
		{
			unsigned n = linenum();
			push('G');
			jump(n);
		}
		break;
	case TK_RETURN:
		while (sp && stack[sp - 1].type != 'G')
			sp--;
		if (!sp)
			error(ERR_RETURN);
		sp--;
		curline = stack[sp].line;
		ip = stack[sp].ip;
		if (!curline)
			running = 0;
		break;
	case TK_LET:
		let();
		break;
	case TK_REM:
	case TK_DATA:
		while (*ip)
			ip++;
		break;
	case TK_CLEAR:
		clearvars();
		break;
	case TK_LIST:
		list();
		break;
	case TK_RUN:
		run();
		break;
	case TK_STOP:
	case TK_END:
		if (curline) {
			contline = curline;
			contip = ip;
		}
		if (c == TK_STOP && curline)
		{
			fputs("Break in ", stdout);
			puts(numstr(LNUM(curline)));
		}
		running = 0;
		curline = NULL;
		while (*ip)
			ip++;
		break;
	case TK_CONT:
		if (!contline)
			error(ERR_CONT);
		curline = contline;
		ip = contip;
		running = 1;
		break;
	case TK_DIM:
		dimstmt();
		break;
	case TK_RANDOMIZE:
		srand(endstmt() ? (unsigned)rand() + (unsigned)(long)&c : intexpr());
		break;
	case TK_READ:
		readstmt();
		break;
	case TK_RESTORE:
		dataptr = NULL;
		break;
	case TK_ON:
		onstmt();
		break;
	case TK_CLS:
		fputs("\033[H\033[J", stdout);
		column = 0;
		break;
	case TK_SAVE:
		save();
		break;
	case TK_LOAD:
		load();
		break;
	case TK_NEW:
		progend = prog;
		clearvars();
		running = 0;
		curline = NULL;
		break;
	case TK_BYE:
	case TK_SYSTEM:
		exit(0);
	case TK_TRON:
		trace = 1;
		break;
	case TK_TROFF:
		trace = 0;
		break;
	default:
		error(ERR_SYNTAX);
	}
}

/* Run statements from ip until the program stops */
static void execute(void)
{
	for (;;) {
		if (stopkey) {
			stopkey = 0;
			if (curline) {
				contline = curline;
				contip = ip;
			}
			error(ERR_BREAK);
		}
		statement();
		if (jumped) {
			jumped = 0;
			continue;
		}
		skipsp();
		if (*ip == ':') {
			ip++;
			continue;
		}
		if (*ip == TK_ELSE) {
			/* the ELSE of an IF that was true: skip the rest */
			while (*ip)
				ip++;
		}
		if (*ip)
			error(ERR_SYNTAX);
		if (!running || !curline)
			return;
		curline = LNEXT(curline);
		if (curline >= progend) {
			running = 0;
			curline = NULL;
			return;
		}
		if (trace)
		{
			putchar('<');
			fputs(numstr(LNUM(curline)), stdout);
			putchar('>');
		}
		ip = LTEXT(curline);
	}
}

/* A typed (or loaded) line: store it or run it */
static void enter(char *line)
{
	char *p = line;
	unsigned n = 0;
	unsigned len;
	while (*p == ' ')
		p++;
	if (isdigit(*p)) {
		long v = 0;
		while (isdigit(*p))
			v = v * 10 + *p++ - '0';
		if (v < 1 || v > 65529L)
			error(ERR_SYNTAX);
		n = v;
		len = tokenize(p);
		storeline(n, tokbuf, len);
		return;
	}
	tokenize(p);
	curline = NULL;
	running = 0;
	jumped = 0;
	ip = tokbuf;
	execute();
	if (column)
		putchar('\n');
	column = 0;
	puts("Ready");
}

static void sigint(int s)
{
	signal(SIGINT, sigint);
	stopkey = 1;
}

int main(int argc, char *argv[])
{
	char line[256];
	unsigned n;

	/* Three quarters of the free memory for the program, the rest for
	   variables, strings and the stdio buffers. The free memory is
	   what lies between the end of the data and the stack; asking
	   malloc for too much makes the kernel complain. */
	{
		long avail = (char *)&n - (char *)sbrk(0) - 2048;
		if (avail < 1024) {
			fputs("basic: not enough memory\n", stderr);
			return 1;
		}
		memsize = avail / 4 * 3;
		prog = malloc(memsize);
		if (!prog) {
			fputs("basic: not enough memory\n", stderr);
			return 1;
		}
	}
	progend = prog;
	memend = prog + memsize;
	signal(SIGINT, sigint);

	if (argc > 1) {
		if (setjmp(onerror) == 0) {
			strcpy(line, "LOAD \"");
			strncat(line, argv[1], 60);
			strcat(line, "\"");
			enter(line);
			strcpy(line, "RUN");
			enter(line);
		}
		return 0;
	}
	fputs("Fuzix BASIC 1.0\n", stdout);
	fputs(numstr(memsize), stdout);
	puts(" bytes free");
	puts("Ready");
	for (;;) {
		if (setjmp(onerror))
			puts("Ready");
		stopkey = 0;
		do {
			column = 0;
			if (!fgets(line, sizeof(line), stdin))
				return 0;
			if (setjmp(onerror) == 0)
				enter(line);
			else
				puts("Ready");
		} while (1);
	}
}
