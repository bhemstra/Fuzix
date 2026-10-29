/*
 *	Turn a raw TRS-80 Model II disk image into an ImageDisk (.IMD) file
 *
 *	The raw image is laid out as
 *	cylinder 0 side 0	26 x 128 byte sectors, single density
 *	cylinder 1-76 side 0	26 x 256 byte sectors, double density
 *	(and with -d each cylinder 1-76 also has side 1 after side 0, while
 *	 cylinder 0 side 1 is written as double density as well)
 *
 *	IMD is understood by MAME, trs80gp and the usual 8" disk writing
 *	tools. Data tracks get a 2:1 interleave.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#define NCYL	77
#define NSEC	26

static FILE *in, *out;

static void sector_out(const unsigned char *buf, int len)
{
	int i;
	for (i = 1; i < len; i++)
		if (buf[i] != buf[0])
			break;
	if (i == len) {
		/* Compressed: all bytes the same */
		fputc(0x02, out);
		fputc(buf[0], out);
	} else {
		fputc(0x01, out);
		fwrite(buf, len, 1, out);
	}
}

static void track_out(int cyl, int head, int dd)
{
	unsigned char buf[NSEC][256];
	unsigned char map[NSEC];
	int len = dd ? 256 : 128;
	int i, n;

	for (i = 0; i < NSEC; i++) {
		if (fread(buf[i], len, 1, in) != 1) {
			fprintf(stderr, "makeimd: short input at cylinder %d\n", cyl);
			exit(1);
		}
	}
	if (dd) {
		/* 2:1 interleave: 1 14 2 15 ... */
		for (i = 0, n = 0; i < NSEC / 2; i++) {
			map[n++] = i + 1;
			map[n++] = i + 1 + NSEC / 2;
		}
	} else {
		for (i = 0; i < NSEC; i++)
			map[i] = i + 1;
	}
	fputc(dd ? 3 : 0, out);	/* 500K MFM or 500K FM (8" rates) */
	fputc(cyl, out);
	fputc(head, out);
	fputc(NSEC, out);
	fputc(dd ? 1 : 0, out);	/* 256 or 128 byte sectors */
	fwrite(map, NSEC, 1, out);
	for (i = 0; i < NSEC; i++)
		sector_out(buf[map[i] - 1], len);
}

int main(int argc, char *argv[])
{
	int ds = 0;
	int cyl;
	time_t t = time(NULL);
	struct tm *tm = localtime(&t);

	if (argc == 4 && strcmp(argv[1], "-d") == 0) {
		ds = 1;
		argv++;
		argc--;
	}
	if (argc != 3) {
		fprintf(stderr, "%s: [-d] raw imd\n", argv[0]);
		exit(1);
	}
	in = fopen(argv[1], "r");
	if (in == NULL) {
		perror(argv[1]);
		exit(1);
	}
	out = fopen(argv[2], "w");
	if (out == NULL) {
		perror(argv[2]);
		exit(1);
	}
	fprintf(out, "IMD 1.18: %02d/%02d/%04d %02d:%02d:%02d\r\n",
		tm->tm_mday, tm->tm_mon + 1, tm->tm_year + 1900,
		tm->tm_hour, tm->tm_min, tm->tm_sec);
	fprintf(out, "Fuzix TRS-80 Model II disk\r\n\x1A");

	track_out(0, 0, 0);
	if (ds)
		track_out(0, 1, 1);
	for (cyl = 1; cyl < NCYL; cyl++) {
		track_out(cyl, 0, 1);
		if (ds)
			track_out(cyl, 1, 1);
	}
	fclose(out);
	fclose(in);
	return 0;
}
