/*
 *	cc - the C compiler driver for scc
 *
 *	cc [-c] [-v] [-o out] [-Idir] [-Dname[=val]] [-Uname] [-lname]
 *	   file.c ... file.o ... lib.a ...
 *
 *	For each C file: scc0 (preprocessor and tokens), scc1 (front end),
 *	scc2 (code generator). Then sld links with crt0.o, the scc helpers and the C
 *	library unless -c was given.
 */

#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <signal.h>
#include <sys/wait.h>

#define LIB	"/usr/lib/"

static char *cppargs[32];
static int ncpp;
static char *ldargs[64];
static int nld;
static char *libs[16];
static int nlibs;
static char *temps[32];
static int ntemps;
static int verbose;
static char tmpbase[24];

static void put(const char *s)
{
	write(2, s, strlen(s));
}

/* Remove the files a failed stage left behind for obj */
static void rmstage(const char *obj)
{
	static char b[64];
	int j, n;
	if (strlen(obj) > 60)
		return;
	strcpy(b, obj);
	n = strlen(b);
	b[n] = '~';
	b[n + 2] = 0;
	for (j = 0; j < 5; j++) {
		b[n + 1] = "tn123"[j];
		unlink(b);
	}
}

static void cleanup(void)
{
	int i;
	for (i = 0; i < ntemps; i++) {
		unlink(temps[i]);
		rmstage(temps[i]);
	}
}

static void fail(void)
{
	cleanup();
	exit(1);
}

static int run(char **argv)
{
	int pid, status;
	char **a;
	if (verbose) {
		for (a = argv; *a; a++) {
			put(*a);
			put(" ");
		}
		put("\n");
	}
	pid = fork();
	if (pid == -1) {
		put("cc: cannot fork\n");
		fail();
	}
	if (pid == 0) {
		execv(argv[0], argv);
		put("cc: cannot run ");
		put(argv[0]);
		put("\n");
		_exit(127);
	}
	while (waitpid(pid, &status, 0) == -1)
		;
	return status;
}

static char *suffix(const char *name, const char *ext)
{
	const char *b = strrchr(name, '/');
	char *p, *d;
	b = b ? b + 1 : name;
	p = malloc(strlen(b) + strlen(ext) + 1);
	strcpy(p, b);
	d = strrchr(p, '.');
	if (d)
		*d = 0;
	strcat(p, ext);
	return p;
}

static char *tempname(const char *ext)
{
	char *p = malloc(strlen(tmpbase) + strlen(ext) + 1);
	strcpy(p, tmpbase);
	strcat(p, ext);
	temps[ntemps++] = p;
	return p;
}

/* Compile one C file into obj. Returns 0 on success. */
static int compile(char *src, char *obj)
{
	char *av[40];
	int i, n = 0;

	av[n++] = LIB "scc0";
	av[n++] = "-I/usr/include";
	av[n++] = "-I/usr/include/z80";
	av[n++] = "-D__z80__";
	av[n++] = "-D__STDC__";
	av[n++] = "-D__SCC__";
	for (i = 0; i < ncpp; i++)
		av[n++] = cppargs[i];
	av[n++] = src;
	av[n++] = obj;
	av[n] = NULL;
	if (run(av))
		return 1;
	av[0] = LIB "scc1";
	av[1] = obj;
	av[2] = NULL;
	if (run(av))
		return 1;
	av[0] = LIB "scc2";
	if (run(av))
		return 1;
	return 0;
}

int main(int argc, char *argv[])
{
	char *out = "a.out";
	int conly = 0, oset = 0;
	int i, nsrc = 0, err = 0;
	char *a, *obj;
	char *srcs[32];
	int ns = 0;
	unsigned pid = getpid();

	strcpy(tmpbase, "/tmp/cc");
	for (i = 7; pid; pid /= 10)
		tmpbase[i++] = '0' + pid % 10;
	tmpbase[i] = 0;
	signal(SIGINT, (void *)fail);

	ldargs[nld++] = "/usr/bin/sld";
	ldargs[nld++] = "-o";
	nld++;			/* the output name */
	ldargs[nld++] = LIB "crt0.o";

	for (i = 1; i < argc; i++) {
		a = argv[i];
		if (a[0] == '-') {
			switch (a[1]) {
			case 'c':
				conly = 1;
				continue;
			case 'v':
				verbose = 1;
				continue;
			case 'O':
			case 'g':
			case 'w':
				continue;
			case 'o':
				if (++i == argc)
					break;
				out = argv[i];
				oset = 1;
				continue;
			case 'I':
			case 'D':
			case 'U':
				if (ncpp < 30)
					cppargs[ncpp++] = a;
				continue;
			case 'l':
				if (nlibs < 16) {
					char *p = malloc(strlen(a) + 12);
					strcpy(p, LIB "lib");
					strcat(p, a + 2);
					strcat(p, ".a");
					libs[nlibs++] = p;
				}
				continue;
			}
			put("cc: unknown option ");
			put(a);
			put("\n");
			exit(1);
		}
		if (ns < 32)
			srcs[ns++] = a;
	}
	if (!ns) {
		put("usage: cc [-c] [-o out] [-Idir] [-Dname] [-lname] files\n");
		exit(1);
	}
	for (i = 0; i < ns; i++) {
		a = srcs[i];
		if (strlen(a) > 2 && strcmp(a + strlen(a) - 2, ".c") == 0) {
			nsrc++;
			if (conly)
				obj = oset && ns == 1 ? out : suffix(a, ".o");
			else {
				char ext[4];
				ext[0] = 'a' + nsrc;
				ext[1] = '.';
				ext[2] = 'o';
				ext[3] = 0;
				obj = tempname(ext);
			}
			if (compile(a, obj)) {
				err = 1;
				rmstage(obj);
				unlink(obj);
				continue;
			}
			ldargs[nld++] = obj;
		} else
			ldargs[nld++] = a;
		if (nld > 50) {
			put("cc: too many files\n");
			fail();
		}
	}
	if (err || conly) {
		cleanup();
		return err;
	}
	ldargs[2] = out;
	ldargs[nld++] = LIB "sccrt.o";
	for (i = 0; i < nlibs; i++)
		ldargs[nld++] = libs[i];
	ldargs[nld++] = LIB "libc.a";
	ldargs[nld++] = LIB "libz80.a";
	ldargs[nld] = NULL;
	err = run(ldargs) != 0;
	cleanup();
	return err;
}
