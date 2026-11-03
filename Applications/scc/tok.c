/*
 *	scc0: preprocessor and tokenizer of scc
 *
 *	scc0 [-Idir] [-Dname[=value]] [-Uname] file.c out
 *
 *	Reads C source, handles the preprocessor directives and writes
 *	out~t (tokens) and out~n (identifier names).
 *
 *	The preprocessor works on tokens: macro bodies and arguments are
 *	kept in the same compact form as the output, which keeps the memory
 *	needed for the system headers small.
 *
 *	Each identifier that reaches the output gets a number. The names
 *	file holds the name of identifier n in a NAMEREC byte record at
 *	n * NAMEREC, so the later passes only need the number in memory.
 *
 *	Token stream: one byte per token (see ir.h), followed by
 *	T_ID: identifier number (word)
 *	T_NUM: value (word)
 *	T_STR: length (byte), bytes
 *	T_LINE: line number (word), before the first token of a new line
 *	T_FILE: length (byte), name, when the file name changes
 */

#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include "ir.h"

/* Internal token codes (never in the output) */
#define T_NL		6	/* end of line (directives only) */
#define M_ARG		7	/* macro body: parameter n */
#define M_STR		8	/* macro body: #parameter n */
#define M_PASTE		9	/* macro body: ## */
#define M_END		10	/* end of a buffer */

static int tfd, nfd;
static u8 errors;

static void fatal(const char *m);

/*
 *	Memory: an arena for things that live until the end
 */
static u8 *arena;
static u16 arenafree;

static void *alloc(u16 n)
{
	u8 *p;
	if (n > arenafree) {
		u16 g = n > 512 ? n : 512;
		p = sbrk(g);
		if (p == (u8 *)-1)
			fatal("out of memory");
		if (p != arena + arenafree) {
			arena = p;
			arenafree = 0;
		}
		arenafree += g;
	}
	p = arena;
	arena += n;
	arenafree -= n;
	return p;
}

/*
 *	Identifiers
 */
struct id {
	struct id *next;
	u8 *macro;		/* body, NULL if not a macro */
	u16 num;		/* output number, NOID if not yet, or
				   KW + token for a keyword */
	u8 info;		/* parameters (OBJLIKE: none), ACTIVE */
	char s[1];
};

#define NOID	0xFFFF
#define KW	0xFE00
#define OBJLIKE	0x7F
#define ACTIVE	0x80
#define NPARAM(m)	((m)->info & 0x7F)
#define NHASH	128
static struct id *hashtab[NHASH];
static u16 nout;

static struct id *lookup(const char *w, u8 make)
{
	const char *p = w;
	u8 h = 0;
	struct id *n;
	while (*p)
		h = (h << 1) + *p++;
	h &= NHASH - 1;
	for (n = hashtab[h]; n; n = n->next)
		if (strcmp(n->s, w) == 0)
			return n;
	if (!make)
		return NULL;
	n = alloc(sizeof(struct id) + (p - w));
	memset(n, 0, sizeof(struct id));
	strcpy(n->s, w);
	n->num = NOID;
	n->next = hashtab[h];
	hashtab[h] = n;
	return n;
}

static const char *keywords[] = {
	"auto", "break", "case", "char", "const", "continue", "default",
	"do", "double", "else", "enum", "extern", "float", "for", "goto",
	"if", "int", "long", "register", "return", "short", "signed",
	"sizeof", "static", "struct", "switch", "typedef", "union",
	"unsigned", "void", "volatile", "while"
};

static struct id *id_defined, *id_line, *id_file;

/*
 *	Output
 */
static u8 obuf[256];
static u16 on;

static void oflush(void)
{
	if (on && write(tfd, obuf, on) != on)
		fatal("write error");
	on = 0;
}

static void ob(u8 c)
{
	if (on == sizeof(obuf))
		oflush();
	obuf[on++] = c;
}

static void ow(u16 w)
{
	ob(w);
	ob(w >> 8);
}

/*
 *	Source files
 */
struct src {
	int fd;
	long off;		/* file position while closed */
	u16 pos, len;
	u16 line;
	char *name;
	u8 buf[256];
};

#define NSRC 8
static struct src *srcs[NSRC];
static struct src *cur;
static u8 nsrc;
static int c;			/* current character */
static int peekc = -1;
static u8 bol = 1;
static u8 dirmode;		/* reading a directive: newline is a token */
static u8 noid;			/* lex: leave identifiers in word only */

static char *incdirs[8];
static u8 nincdirs;

static void where(void)
{
	char *n = cur ? cur->name : "scc0";
	write(2, n, strlen(n));
	if (cur) {
		char b[8], *p = b + 7;
		u16 l = cur->line;
		*p = 0;
		do {
			*--p = '0' + l % 10;
			l /= 10;
		} while (l);
		write(2, ":", 1);
		write(2, p, strlen(p));
	}
	write(2, ": ", 2);
}

static void fatal(const char *m)
{
	where();
	write(2, m, strlen(m));
	write(2, "\n", 1);
	exit(1);
}

static void error(const char *m)
{
	where();
	write(2, m, strlen(m));
	write(2, "\n", 1);
	if (++errors > 10)
		exit(1);
}

static int rdc(void)
{
	int r;
	if (peekc >= 0) {
		r = peekc;
		peekc = -1;
		return r;
	}
	if (cur->pos == cur->len) {
		if (cur->fd < 0)
			return -1;
		r = read(cur->fd, cur->buf, sizeof(cur->buf));
		if (r <= 0)
			return -1;
		cur->len = r;
		cur->pos = 0;
	}
	return cur->buf[cur->pos++];
}

static u8 pushsrc(char *name, int fd)
{
	struct src *s;
	if (nsrc == NSRC) {
		error("includes nested too deeply");
		return 0;
	}
	if (!srcs[nsrc])
		srcs[nsrc] = alloc(sizeof(struct src));
	/* Close the including file meanwhile: a process has few files */
	if (cur && cur->fd > 0) {
		cur->off = lseek(cur->fd, 0L, SEEK_CUR);
		close(cur->fd);
		cur->fd = 0;
	}
	s = srcs[nsrc];
	s->fd = fd;
	s->pos = s->len = 0;
	s->line = 1;
	s->name = name;
	cur = s;
	nsrc++;
	c = rdc();
	bol = 1;
	return 1;
}

/* At the end of a file: back to the including one */
static u8 popsrc(void)
{
	if (nsrc == 1)
		return 0;
	if (cur->fd > 0)
		close(cur->fd);
	nsrc--;
	cur = srcs[nsrc - 1];
	cur->fd = open(cur->name, O_RDONLY);
	if (cur->fd == -1)
		fatal("cannot reopen");
	lseek(cur->fd, cur->off, SEEK_SET);
	c = '\n';		/* the #include line ends here */
	return 1;
}

static int openinc(const char *n, u8 local)
{
	char b[80];
	u8 i;
	int fd;
	if (local) {
		/* the directory of the current file first */
		char *p = strrchr(cur->name, '/');
		b[0] = 0;
		if (p && p - cur->name < 40) {
			memcpy(b, cur->name, p - cur->name + 1);
			b[p - cur->name + 1] = 0;
		}
		strcat(b, n);
		fd = open(b, O_RDONLY);
		if (fd >= 0)
			goto found;
	}
	for (i = 0; i < nincdirs; i++) {
		strcpy(b, incdirs[i]);
		strcat(b, "/");
		strcat(b, n);
		fd = open(b, O_RDONLY);
		if (fd >= 0)
			goto found;
	}
	return -1;
found:
	{
		char *nm = alloc(strlen(b) + 1);
		strcpy(nm, b);
		pushsrc(nm, fd);
	}
	return fd;
}

/*
 *	The lexer. A token is t with tv (number or identifier) or the
 *	string in sbuf/slen.
 */
static u8 t;
static u16 tv;
static struct id *tid;
static u8 sbuf[256];
static u8 slen;
static char word[64];

static u8 isid(int ch)
{
	return (ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z') || ch == '_' ||
		(ch >= '0' && ch <= '9');
}

static u8 digit(int ch, u8 base)
{
	u8 d;
	if (ch >= '0' && ch <= '9')
		d = ch - '0';
	else if (ch >= 'a' && ch <= 'f')
		d = ch - 'a' + 10;
	else if (ch >= 'A' && ch <= 'F')
		d = ch - 'A' + 10;
	else
		return 255;
	return d < base ? d : 255;
}

static u16 number(u8 base)
{
	u16 v = 0;
	u8 d;
	while ((d = digit(c, base)) != 255) {
		v = v * base + d;
		c = rdc();
	}
	return v;
}

static u8 charval(void)
{
	u8 v;
	if (c != '\\') {
		v = c;
		c = rdc();
		return v;
	}
	c = rdc();
	v = c;
	c = rdc();
	switch (v) {
	case 'n': return 10;
	case 't': return 9;
	case 'r': return 13;
	case 'b': return 8;
	case 'f': return 12;
	case 'v': return 11;
	case 'a': return 7;
	case 'e': return 27;
	case 'x':
		return number(16);
	}
	if (v >= '0' && v <= '7') {
		u8 n = 1;
		v -= '0';
		while (n++ < 3 && c >= '0' && c <= '7') {
			v = v * 8 + c - '0';
			c = rdc();
		}
	}
	return v;
}

static void skipspace(void)
{
	for (;;) {
		if (c == '\\') {
			c = rdc();
			if (c == '\n') {
				cur->line++;
				c = rdc();
				continue;
			}
			peekc = c;
			c = '\\';
			return;
		}
		if (c == ' ' || c == '\t' || c == '\r' || c == '\f' || c == '\v') {
			c = rdc();
			continue;
		}
		if (c == '/') {
			c = rdc();
			if (c == '*') {
				int last = 0;
				c = rdc();
				while (c != -1 && !(last == '*' && c == '/')) {
					if (c == '\n')
						cur->line++;
					last = c;
					c = rdc();
				}
				c = rdc();
				continue;
			}
			if (c == '/') {
				while (c != '\n' && c != -1)
					c = rdc();
				continue;
			}
			peekc = c;
			c = '/';
		}
		return;
	}
}

static const char ops2[] = "->++--<<>><=>===!=&&||";
static const char aops[] = "+-*/%&|^";

static void directive(void);
static u8 skipping(void);

/* Read the next token from the source files */
static void lex(void)
{
	char *p;
	for (;;) {
		skipspace();
		if (c == '\n') {
			if (dirmode) {
				t = T_NL;
				return;
			}
			cur->line++;
			bol = 1;
			c = rdc();
			continue;
		}
		if (c == -1) {
			if (dirmode) {
				t = T_NL;
				return;
			}
			if (popsrc())
				continue;
			t = T_EOF;
			return;
		}
		if (c == '#' && bol) {
			c = rdc();
			directive();
			continue;
		}
		if (!dirmode && skipping()) {
			/* a part that is not compiled: skip the line */
			while (c != '\n' && c != -1) {
				if (c == '/') {
					c = rdc();
					if (c == '*' || c == '/') {
						peekc = c;
						c = '/';
						skipspace();
					}
					continue;
				}
				c = rdc();
			}
			continue;
		}
		break;
	}
	bol = 0;
	if (isid(c) && !(c >= '0' && c <= '9')) {
		p = word;
		while (isid(c)) {
			if (p < word + sizeof(word) - 1)
				*p++ = c;
			c = rdc();
		}
		*p = 0;
		tid = noid ? NULL : lookup(word, 1);
		t = T_ID;
		return;
	}
	if (c >= '0' && c <= '9') {
		if (c == '0') {
			c = rdc();
			if (c == 'x' || c == 'X') {
				c = rdc();
				tv = number(16);
			} else
				tv = number(8);
		} else
			tv = number(10);
		while (c == 'u' || c == 'U' || c == 'l' || c == 'L')
			c = rdc();
		t = T_NUM;
		return;
	}
	if (c == '\'') {
		c = rdc();
		tv = charval();
		if (c == '\'')
			c = rdc();
		else
			error("bad character constant");
		t = T_NUM;
		return;
	}
	if (c == '"') {
		c = rdc();
		slen = 0;
		while (c != '"' && c != -1 && c != '\n') {
			u8 v = charval();
			if (slen == 255)
				fatal("string too long");
			sbuf[slen++] = v;
		}
		c = rdc();
		t = T_STR;
		return;
	}
	t = c;
	c = rdc();
	if (t == '.' && c == '.') {
		c = rdc();
		if (c == '.')
			c = rdc();
		t = T_ELLIPSIS;
		return;
	}
	for (p = (char *)ops2; *p; p += 2) {
		if (p[0] == t && p[1] == c) {
			t = T_ARROW + (p - ops2) / 2;
			c = rdc();
			if ((t == T_SHL || t == T_SHR) && c == '=') {
				c = rdc();
				t = t == T_SHL ? T_SHLEQ : T_SHREQ;
			}
			return;
		}
	}
	if (c == '=') {
		p = strchr(aops, t);
		if (p) {
			c = rdc();
			t = T_ADDEQ + (p - aops);
		}
	}
}

/*
 *	Token buffers (macro bodies, arguments, expansions)
 */
static u8 *bp;			/* where put() writes */
static u8 *blimit;

static void put(u8 b)
{
	if (bp == blimit)
		fatal("macro too large");
	*bp++ = b;
}

/* Store the current token at bp */
static void puttok(void)
{
	u8 i;
	put(t);
	switch (t) {
	case T_ID:
		/* in buffers an identifier is its address */
		for (i = 0; i < sizeof(tid); i++)
			put(((u8 *)&tid)[i]);
		break;
	case T_NUM:
		put(tv);
		put(tv >> 8);
		break;
	case T_STR:
		put(slen);
		for (i = 0; i < slen; i++)
			put(sbuf[i]);
		break;
	case M_ARG:
	case M_STR:
		put(tv);
		break;
	}
}

/* Read the token at p into t, return the next position */
static u8 *gettok(u8 *p)
{
	t = *p++;
	switch (t) {
	case T_ID:
		memcpy(&tid, p, sizeof(tid));
		p += sizeof(tid);
		break;
	case T_NUM:
		tv = p[0] | (p[1] << 8);
		p += 2;
		break;
	case T_STR:
		slen = *p++;
		memcpy(sbuf, p, slen);
		p += slen;
		break;
	case M_ARG:
	case M_STR:
		tv = *p++;
		break;
	}
	return p;
}

/*
 *	Expansion stack: macro text being read before the source again
 */
struct exp {
	u8 *p;
	struct id *mac;
	u8 *mem;		/* start of its space on the scratch stack */
};

#define NEXP 24
static struct exp exps[NEXP];
static u8 nexp;
static u8 scratch[1280];
static u8 *ssp = scratch;	/* scratch stack pointer */

static u8 havepush;
static u8 pt, plen;
static u16 pv;
static struct id *pid;
static u8 pbuf[256];

static void pushback(void)
{
	havepush = 1;
	pt = t;
	pv = tv;
	pid = tid;
	plen = slen;
	if (t == T_STR)
		memcpy(pbuf, sbuf, slen);
}

/* The next token, from an expansion or the source */
static void rawtok(void)
{
	struct exp *e;
	if (havepush) {
		havepush = 0;
		t = pt;
		tv = pv;
		tid = pid;
		slen = plen;
		if (t == T_STR)
			memcpy(sbuf, pbuf, slen);
		return;
	}
	while (nexp) {
		e = exps + nexp - 1;
		if (*e->p != M_END) {
			e->p = gettok(e->p);
			return;
		}
		if (e->mac)
			e->mac->info &= ~ACTIVE;
		if (e->mem)
			ssp = e->mem;
		nexp--;
	}
	lex();
}

static void pushexp(u8 *p, struct id *mac, u8 *mem)
{
	if (nexp == NEXP)
		fatal("macros nested too deeply");
	exps[nexp].p = p;
	exps[nexp].mac = mac;
	exps[nexp].mem = mem;
	nexp++;
	if (mac)
		mac->info |= ACTIVE;
}

/* Name of a token, for # and ## */
static const char *tokname(void)
{
	static char b[8];
	char *p = b + 7;
	u16 v = tv;
	if (t == T_ID)
		return tid->s;
	if (t == T_NUM) {
		*p = 0;
		do {
			*--p = '0' + v % 10;
			v /= 10;
		} while (v);
		return p;
	}
	b[0] = t;
	b[1] = 0;
	return b;
}

/* Expand a function like macro whose name has been read */
static u8 expandfn(struct id *m)
{
	u8 *args[16];
	u8 *start = ssp, *body, *out;
	u8 n = 0, depth = 0;
	u16 len;

	rawtok();
	if (t != '(') {
		pushback();
		return 0;
	}
	bp = ssp;
	blimit = scratch + sizeof(scratch);
	args[0] = bp;
	for (;;) {
		rawtok();
		if (t == T_EOF)
			fatal("end of file in macro arguments");
		if (t == '(')
			depth++;
		else if (t == ')') {
			if (depth == 0)
				break;
			depth--;
		} else if (t == ',' && depth == 0) {
			put(M_END);
			if (++n == 16)
				fatal("too many macro arguments");
			args[n] = bp;
			continue;
		}
		puttok();
	}
	put(M_END);
	if (args[n] + 1 != bp || n)
		n++;
	if (n != NPARAM(m) && !(NPARAM(m) == 1 && n == 0))
		error("wrong number of macro arguments");
	/* Substitute */
	out = bp;
	body = m->macro;
	while (*body != M_END) {
		body = gettok(body);
		if (t == M_ARG) {
			u8 *a = tv < n ? args[tv] : (u8 *)"\012";
			while (*a != M_END) {
				a = gettok(a);
				puttok();
			}
		} else if (t == M_STR) {
			/* #arg: the tokens as a string */
			u8 *a = tv < n ? args[tv] : (u8 *)"\012";
			u8 sb[128], sl = 0;
			const char *s;
			while (*a != M_END) {
				a = gettok(a);
				if (t == T_STR) {
					memcpy(sb + sl, sbuf, slen < 100 - sl ? slen : 0);
					sl += slen < 100 - sl ? slen : 0;
					continue;
				}
				s = tokname();
				while (*s && sl < 120)
					sb[sl++] = *s++;
			}
			memcpy(sbuf, sb, sl);
			slen = sl;
			t = T_STR;
			puttok();
		} else if (t == M_PASTE) {
			/* a ## b: join the previous token and the next */
			u8 *last = out, *q = out;
			char nb[64];
			while (q < bp) {
				last = q;
				q = gettok(q);
			}
			if (last == bp)
				continue;
			gettok(last);
			strcpy(nb, tokname());
			bp = last;
			body = gettok(body);
			if (t == M_ARG) {
				u8 *a = tv < n ? args[tv] : (u8 *)"\012";
				if (*a != M_END)
					gettok(a);
			}
			strcat(nb, tokname());
			if (nb[0] >= '0' && nb[0] <= '9') {
				t = T_NUM;
				tv = atoi(nb);
			} else {
				t = T_ID;
				tid = lookup(nb, 1);
			}
			puttok();
		} else
			puttok();
	}
	put(M_END);
	/* Move the expansion down over the arguments */
	len = bp - out;
	memmove(start, out, len);
	ssp = start + len;
	pushexp(start, m, start);
	return 1;
}

/* The next token with macros expanded */
static void tok(void)
{
	struct id *m;
	for (;;) {
		rawtok();
		if (t != T_ID)
			return;
		m = tid;
		if (m == id_line) {
			t = T_NUM;
			tv = cur->line;
			return;
		}
		if (m == id_file) {
			t = T_STR;
			slen = strlen(cur->name);
			memcpy(sbuf, cur->name, slen);
			return;
		}
		if (!m->macro || (m->info & ACTIVE))
			return;
		if (NPARAM(m) == OBJLIKE)
			pushexp(m->macro, m, NULL);
		else if (!expandfn(m)) {
			/* not a call: the name itself, the next token is
			   pushed back */
			t = T_ID;
			tid = m;
			return;
		}
	}
}

/*
 *	Conditionals
 */
#define NCOND 32
static u8 conds[NCOND];		/* bit 0: this branch on, bit 1: one done */
static u8 ncond;

static u8 skipping(void)
{
	u8 i;
	for (i = 0; i < ncond; i++)
		if (!(conds[i] & 1))
			return 1;
	return 0;
}

/* #if expressions */
static int expr(u8 prec);

static int primary(void)
{
	int v;
	u8 paren;
	tok();
	switch (t) {
	case T_NUM:
		return tv;
	case T_ID:
		if (tid == id_defined) {
			rawtok();
			paren = t == '(';
			if (paren)
				rawtok();
			v = t == T_ID && tid->macro != NULL;
			if (paren)
				rawtok();
			return v;
		}
		return 0;
	case '(':
		v = expr(1);
		if (t != ')')
			error("missing ) in #if");
		return v;
	case '!':
		return !primary();
	case '-':
		return -primary();
	case '~':
		return ~primary();
	case '+':
		return primary();
	}
	error("bad #if expression");
	return 0;
}

static u8 binprec(u8 op)
{
	switch (op) {
	case '*': case '/': case '%': return 10;
	case '+': case '-': return 9;
	case T_SHL: case T_SHR: return 8;
	case '<': case '>': case T_LE: case T_GE: return 7;
	case T_EQ: case T_NE: return 6;
	case '&': return 5;
	case '^': return 4;
	case '|': return 3;
	case T_ANDAND: return 2;
	case T_OROR: return 1;
	}
	return 0;
}

/* Parse an expression; t is left on the token after it */
static int expr(u8 minprec)
{
	int a = primary(), b;
	u8 op, p;
	tok();
	for (;;) {
		if (t == '?' && minprec <= 1) {
			int x, y;
			x = expr(1);
			if (t != ':')
				error("missing : in #if");
			y = expr(1);
			a = a ? x : y;
			continue;
		}
		p = binprec(t);
		if (!p || p < minprec)
			return a;
		op = t;
		b = expr(p + 1);
		switch (op) {
		case '*': a *= b; break;
		case '/': a = b ? a / b : 0; break;
		case '%': a = b ? a % b : 0; break;
		case '+': a += b; break;
		case '-': a -= b; break;
		case T_SHL: a <<= b; break;
		case T_SHR: a >>= b; break;
		case '<': a = a < b; break;
		case '>': a = a > b; break;
		case T_LE: a = a <= b; break;
		case T_GE: a = a >= b; break;
		case T_EQ: a = a == b; break;
		case T_NE: a = a != b; break;
		case '&': a &= b; break;
		case '^': a ^= b; break;
		case '|': a |= b; break;
		case T_ANDAND: a = a && b; break;
		case T_OROR: a = a || b; break;
		}
	}
}

static u8 ifexpr(void)
{
	int v;
	u8 onexp = nexp;
	v = expr(1);
	if (t != T_NL)
		error("junk after #if expression");
	nexp = onexp;
	return v != 0;
}

/* Skip to the end of the directive line */
static void eol(void)
{
	while (c != '\n' && c != -1)
		c = rdc();
}

/* #define */
static u8 param(char *params, u8 np)
{
	u8 i;
	for (i = 0; i < np; i++)
		if (strcmp(word, params + i * NAMEREC) == 0)
			return i;
	return 0xFF;
}

static void define(void)
{
	struct id *m;
	char params[16 * NAMEREC];
	u8 np = OBJLIKE, i;
	u8 tmp[400];

	lex();
	if (t != T_ID) {
		error("bad #define");
		return;
	}
	m = tid;
	/* The parameter names are only needed here: keep them out of the
	   identifier table */
	noid = 1;
	if (c == '(') {
		/* function like */
		np = 0;
		c = rdc();
		lex();
		while (t == T_ID) {
			if (np == 16)
				fatal("too many macro parameters");
			strcpy(params + NAMEREC * np++, word);
			lex();
			if (t != ',')
				break;
			lex();
		}
		if (t == T_ELLIPSIS)
			lex();
		if (t != ')')
			error("bad macro parameters");
	}
	bp = tmp;
	blimit = tmp + sizeof(tmp) - 1;
	for (;;) {
		lex();
		if (t == T_NL)
			break;
		if (t == '#' && np != OBJLIKE) {
			lex();
			if (t == '#') {
				put(M_PASTE);
				continue;
			}
			i = t == T_ID ? param(params, np) : 0xFF;
			if (i == 0xFF) {
				error("# needs a parameter");
				continue;
			}
			put(M_STR);
			put(i);
			continue;
		}
		if (t == '#')
			continue;
		if (t == T_ID) {
			i = np != OBJLIKE ? param(params, np) : 0xFF;
			if (i != 0xFF) {
				put(M_ARG);
				put(i);
				continue;
			}
			tid = lookup(word, 1);
		}
		puttok();
	}
	noid = 0;
	put(M_END);
	m->macro = alloc(bp - tmp);
	memcpy(m->macro, tmp, bp - tmp);
	m->info = np;
}

static void include(void)
{
	char n[64], *p = n;
	int end;
	skipspace();
	if (c == '"')
		end = '"';
	else if (c == '<')
		end = '>';
	else {
		error("bad #include");
		eol();
		return;
	}
	c = rdc();
	while (c != end && c != '\n' && c != -1) {
		if (p < n + sizeof(n) - 1)
			*p++ = c;
		c = rdc();
	}
	*p = 0;
	eol();
	/* The rest of this file goes on with the newline after the
	   included file (see popsrc) */
	if (openinc(n, end == '"') < 0)
		error("cannot find include file");
}

static void directive(void)
{
	u8 skip = skipping();
	const char *d;

	dirmode = 1;
	lex();
	if (t == T_NUM) {
		/* # line "file" from an earlier preprocessor */
		cur->line = tv - 1;
		t = T_NL;
	}
	if (t != T_ID) {
		if (!skip && t != T_NL)
			error("bad directive");
		eol();
		dirmode = 0;
		return;
	}
	d = tid->s;
	if (strcmp(d, "ifdef") == 0 || strcmp(d, "ifndef") == 0) {
		u8 v;
		lex();
		v = t == T_ID && tid->macro != NULL;
		if (d[2] == 'n')
			v = !v;
		if (ncond == NCOND)
			fatal("#if nested too deeply");
		conds[ncond++] = v ? 3 : 0;
	} else if (strcmp(d, "if") == 0) {
		u8 v = skip ? 0 : ifexpr();
		if (ncond == NCOND)
			fatal("#if nested too deeply");
		conds[ncond++] = v ? 3 : 0;
	} else if (strcmp(d, "elif") == 0) {
		if (!ncond)
			error("#elif without #if");
		else if (conds[ncond - 1] & 2)
			conds[ncond - 1] = 2;
		else {
			ncond--;
			if (!skipping() && ifexpr())
				conds[ncond] = 3;
			else
				conds[ncond] = 0;
			ncond++;
		}
	} else if (strcmp(d, "else") == 0) {
		if (!ncond)
			error("#else without #if");
		else
			conds[ncond - 1] = (conds[ncond - 1] & 2) ? 2 : 3;
	} else if (strcmp(d, "endif") == 0) {
		if (!ncond)
			error("#endif without #if");
		else
			ncond--;
	} else if (skip) {
		/* nothing else matters in a skipped part */
	} else if (strcmp(d, "define") == 0) {
		define();
	} else if (strcmp(d, "undef") == 0) {
		lex();
		if (t == T_ID)
			tid->macro = NULL;
	} else if (strcmp(d, "include") == 0) {
		dirmode = 0;
		include();
		return;
	} else if (strcmp(d, "error") == 0) {
		fatal("#error");
	} else if (strcmp(d, "line") == 0) {
		lex();
		if (t == T_NUM)
			cur->line = tv - 1;
	}
	/* pragma, ident, warning and the rest are ignored */
	eol();
	dirmode = 0;
}

/*
 *	Output
 */
static struct src *lastsrc;
static u16 lastline;

static void emit(void)
{
	u8 i;
	if (cur != lastsrc || (cur && cur->name != lastsrc->name)) {
		ob(T_FILE);
		i = strlen(cur->name);
		ob(i);
		while (i--)
			ob(cur->name[strlen(cur->name) - 1 - i]);
		lastsrc = cur;
		lastline = 0;
	}
	if (cur->line != lastline) {
		ob(T_LINE);
		ow(cur->line);
		lastline = cur->line;
	}
	switch (t) {
	case T_ID:
		if ((tid->num & 0xFF00) == KW) {
			ob(tid->num);
			return;
		}
		if (tid->num == NOID) {
			char r[NAMEREC];
			memset(r, 0, NAMEREC);
			strncpy(r, tid->s, NAMEREC - 1);
			if (write(nfd, r, NAMEREC) != NAMEREC)
				fatal("write error");
			tid->num = nout++;
		}
		ob(T_ID);
		ow(tid->num);
		return;
	case T_NUM:
		ob(T_NUM);
		ow(tv);
		return;
	case T_STR:
		ob(T_STR);
		ob(slen);
		for (i = 0; i < slen; i++)
			ob(sbuf[i]);
		return;
	}
	ob(t);
}

static int create(const char *base, char n)
{
	char *p = alloc(strlen(base) + 3);
	int fd;
	strcpy(p, base);
	strcat(p, "~t");
	p[strlen(p) - 1] = n;
	fd = open(p, O_WRONLY | O_CREAT | O_TRUNC, 0600);
	if (fd == -1)
		fatal("cannot create temporary file");
	return fd;
}

/* -Dname[=value] */
static void cmddef(char *s)
{
	static char line[80];
	char *e;
	strcpy(line, s);
	e = strchr(line, '=');
	if (e)
		*e = ' ';
	else
		strcat(line, " 1");
	strcat(line, "\n");
	pushsrc("<command line>", -1);
	strcpy((char *)cur->buf, line);
	cur->len = strlen(line);
	cur->pos = 0;
	c = rdc();
	dirmode = 1;
	define();
	dirmode = 0;
	nsrc--;
	cur = NULL;
}

int main(int argc, char *argv[])
{
	int i, fd;
	u8 k;
	char *in = NULL, *out = NULL;
	struct id *n;

	for (k = 0; k <= K_LAST - K_FIRST; k++)
		lookup(keywords[k], 1)->num = KW + K_FIRST + k;
	id_defined = lookup("defined", 1);
	id_line = lookup("__LINE__", 1);
	id_file = lookup("__FILE__", 1);
	for (i = 1; i < argc; i++) {
		char *a = argv[i];
		if (a[0] == '-' && a[1] == 'I' && nincdirs < 8)
			incdirs[nincdirs++] = a + 2;
		else if (a[0] == '-' && a[1] == 'D')
			cmddef(a + 2);
		else if (a[0] == '-' && a[1] == 'U') {
			n = lookup(a + 2, 0);
			if (n)
				n->macro = NULL;
		} else if (!in)
			in = a;
		else
			out = a;
	}
	if (!in || !out) {
		write(2, "usage: scc0 [-Idir] [-Dname] file.c out\n", 40);
		exit(1);
	}
	fd = open(in, O_RDONLY);
	if (fd == -1) {
		write(2, in, strlen(in));
		write(2, ": cannot open\n", 14);
		exit(1);
	}
	tfd = create(out, 't');
	nfd = create(out, 'n');
	pushsrc(in, fd);
	do {
		tok();
		if (t == T_EOF)
			break;
		emit();
	} while (1);
	ob(T_EOF);
	if (ncond)
		error("missing #endif");
	oflush();
	close(tfd);
	close(nfd);
	return errors ? 1 : 0;
}
