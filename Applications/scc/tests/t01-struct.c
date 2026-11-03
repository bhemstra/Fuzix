struct point { int x, y; char tag; };
struct rect { struct point a, b; int area; };
union u { int i; char c[2]; };
typedef struct point Point;

struct point gp = { 3, 4, 'p' };
struct rect gr = { { 1, 2, 'a' }, { 5, 7, 'b' } };
int garr[] = { 10, 20, 30, 40 };
char gs[] = "hello";
char *gps = "world";
char *names[] = { "zero", "one", "two" };
int g2d[2][3] = { { 1, 2, 3 }, { 4, 5, 6 } };
static int sv = 42;

int area(struct rect *r)
{
	return (r->b.x - r->a.x) * (r->b.y - r->a.y);
}

int sum(int *p, int n)
{
	int s = 0;
	while (n--)
		s += *p++;
	return s;
}

int slen(char *s)
{
	char *p = s;
	while (*p)
		p++;
	return p - s;
}

int main(int argc, char *argv[])
{
	struct point lp;
	Point *pp = &lp;
	union u uu;
	int i, j, t;
	int la[5];

	if (gp.x != 3 || gp.y != 4 || gp.tag != 'p')
		return 1;
	if (area(&gr) != 20)
		return 2;
	lp.x = 9;
	pp->y = 11;
	if (lp.y != 11 || pp->x != 9)
		return 3;
	if (sizeof(struct point) != 5 || sizeof(struct rect) != 12)
		return 4;
	uu.i = 0x1234;
	if (uu.c[0] != 0x34 || uu.c[1] != 0x12)
		return 5;
	if (sum(garr, 4) != 100)
		return 6;
	if (sizeof(garr) != 8)
		return 7;
	if (slen(gs) != 5 || slen(gps) != 5 || gs[1] != 'e')
		return 8;
	if (slen(names[2]) != 3 || names[1][1] != 'n')
		return 9;
	t = 0;
	for (i = 0; i < 2; i++)
		for (j = 0; j < 3; j++)
			t += g2d[i][j];
	if (t != 21 || g2d[1][2] != 6)
		return 10;
	for (i = 0; i < 5; i++)
		la[i] = i * i;
	if (la[4] != 16 || sum(la, 5) != 30)
		return 11;
	if (sv != 42)
		return 12;
	gr.area = area(&gr);
	if (gr.area != 20)
		return 13;
	return 0;
}
