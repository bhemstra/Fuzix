/*
 *	scc: read the token stream from scc0, names, memory and messages
 */

#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include "scc.h"

u8 tok;
u16 tokval;
struct name *tokname;
char strbuf[256];
u16 strlen_;
u16 line = 1;
u8 errors;

static int infd, namefd;
static u8 ibuf[256];
static u16 ipos, ilen;
static char fname[64] = "stdin";

/*
 *	Memory: one arena taken with sbrk, never freed
 */
static u8 *arena;
static u16 arenafree;

void *alloc(u16 n)
{
	u8 *p;
	u16 g;
	if (n > arenafree) {
		g = n > 512 ? n : 512;
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
	memset(p, 0, n);
	return p;
}

/*
 *	Output helpers without stdio
 */
void putstr(int fd, const char *s)
{
	write(fd, s, strlen(s));
}

void putnum(int fd, u16 n)
{
	char b[6];
	char *p = b + 5;
	*p = 0;
	do {
		*--p = '0' + n % 10;
		n /= 10;
	} while (n);
	putstr(fd, p);
}

static void where(void)
{
	putstr(2, fname);
	putstr(2, ":");
	putnum(2, line);
	putstr(2, ": ");
}

static void count(void)
{
	if (++errors > 20)
		fatal("too many errors");
}

void error(const char *m)
{
	where();
	putstr(2, m);
	putstr(2, "\n");
	count();
}

void errorn(const char *m, struct name *n)
{
	where();
	putstr(2, m);
	putstr(2, " '");
	putstr(2, idname(n));
	putstr(2, "'\n");
	count();
}

void fatal(const char *m)
{
	where();
	putstr(2, m);
	putstr(2, "\n");
	exit(1);
}

/*
 *	Names: scc0 numbers the identifiers, we keep a record per number
 *	and read the text from the names file when it is needed.
 */
#define CHUNK 64
static struct name *chunks[48];

struct name *idp(u16 id)
{
	struct name **c = chunks + id / CHUNK;
	struct name *n;
	if (id >= 48 * CHUNK)
		fatal("too many names");
	if (!*c)
		*c = alloc(CHUNK * sizeof(struct name));
	n = *c + id % CHUNK;
	n->id = id;
	return n;
}

const char *idname(struct name *n)
{
	static char buf[NAMEREC];
	lseek(namefd, (long)n->id * NAMEREC, SEEK_SET);
	if (read(namefd, buf, NAMEREC) != NAMEREC)
		strcpy(buf, "?");
	return buf;
}

/*
 *	Tokens
 */
static u8 rb(void)
{
	if (ipos == ilen) {
		int r = read(infd, ibuf, sizeof(ibuf));
		if (r <= 0)
			return T_EOF;
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

void lexinit(int fd, int nfd)
{
	infd = fd;
	namefd = nfd;
	next();
}

static u8 pushedtok;

/* Push back one token (the parser looked one too far) */
void unput(u8 t)
{
	pushedtok = t;
}

void next(void)
{
	u8 i;
	if (pushedtok) {
		tok = pushedtok;
		pushedtok = 0;
		return;
	}
	for (;;) {
		tok = rb();
		switch (tok) {
		case T_LINE:
			line = rw();
			continue;
		case T_FILE:
			strlen_ = rb();
			for (i = 0; i < strlen_; i++) {
				u8 ch = rb();
				if (i < sizeof(fname) - 1)
					fname[i] = ch;
			}
			fname[i < sizeof(fname) - 1 ? i : sizeof(fname) - 1] = 0;
			continue;
		case T_ID:
			tokname = idp(rw());
			return;
		case T_NUM:
			tokval = rw();
			return;
		case T_STR:
			strlen_ = rb();
			for (i = 0; i < strlen_; i++)
				strbuf[i] = rb();
			strbuf[strlen_] = 0;
			return;
		}
		return;
	}
}

u8 accept(u8 t)
{
	if (tok == t) {
		next();
		return 1;
	}
	return 0;
}

void expect(u8 t)
{
	static char m[] = "expected ' '";
	if (tok != t) {
		m[10] = t < 128 ? t : '?';
		error(m);
	} else
		next();
}
