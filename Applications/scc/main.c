/*
 *	scc: a small C compiler for Fuzix (Z80)
 *
 *	scc0 file.i x.o		tokens: x.o~t, x.o~n
 *	scc x.o			front end: x.o~1, x.o~2, x.o~3
 *	scc2 x.o		code generator: x.o
 *
 *	The cc driver runs cpp and these in turn.
 */

#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include "scc.h"

static char *tmp(const char *base, char c)
{
	char *p = alloc(strlen(base) + 3);
	strcpy(p, base);
	strcat(p, "~t");
	p[strlen(p) - 1] = c;
	return p;
}

int main(int argc, char *argv[])
{
	char *tn, *nn;
	int fd, nfd;

	if (argc != 2) {
		putstr(2, "usage: scc file.o\n");
		exit(1);
	}
	tn = tmp(argv[1], 't');
	nn = tmp(argv[1], 'n');
	fd = open(tn, O_RDONLY);
	nfd = open(nn, O_RDONLY);
	if (fd == -1 || nfd == -1) {
		putstr(2, "scc: no input from scc0\n");
		exit(1);
	}
	outinit(argv[1]);
	helpers();
	nocode = 1;
	lexinit(fd, nfd);
	while (tok != T_EOF) {
		if (accept(';'))
			continue;
		declaration(0);
	}
	outfinish();
	close(fd);
	close(nfd);
	unlink(tn);
	unlink(nn);
	return errors ? 1 : 0;
}
