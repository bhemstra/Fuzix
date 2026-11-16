/*
 *	Control the mouse on systems with a kernel mouse driver
 */

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <termios.h>

static int vtmouse(uint8_t r)
{
	int ret = ioctl(0, VTMOUSE, &r);
	if (ret < 0) {
		perror("vtmouse");
		exit(1);
	}
	return ret;
}

static char usagestr[] = { "mouse: [on | off | key | input ]\n" };
static char *mode[3] = { "off.\n", "input.\n", "key.\n" };

static void writes(int fd, const char *p)
{
	write(fd, p, strlen(p));
}

static void usage(void)
{
	writes(2, usagestr);
	exit(1);
}

int main(int argc, char *argv[])
{
	uint8_t r = VTMOUSE_OFF;
	char *p = argv[1];

	if (p) {
		if (strcmp(p, "on") == 0)
			r = VTMOUSE_KEY;
		else if (strcmp(p, "key") == 0)
			r = VTMOUSE_KEY;
		else if (strcmp(p, "input") == 0)
			r = VTMOUSE_INPUT;
		else if (strcmp(p, "off")) {
			usage();
			return 1;
		}
	} else {
		r = vtmouse(VTMOUSE_OFF);
		writes(1, "mouse: mode is currently ");
		if (r < 3)
			writes(1, mode[r]);
		else
			writes(1, "unknown.\n");
	}
	vtmouse(r);
	return 0;
}
