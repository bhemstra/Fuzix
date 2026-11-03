enum colour { RED, GREEN = 5, BLUE };
int sw(int x)
{
	switch (x) {
	case 0: return 10;
	case 1:
	case 2: return 20;
	case -1: return 30;
	case 1000: return 40;
	case RED + 100: return 50;
	default: return 99;
	}
}
int sw2(int x)
{
	int r = 0;
	switch (x) {
	case 1: r += 1;
	case 2: r += 2; break;
	case 3: r = 3;
	}
	return r;
}
int g(int n)
{
	int i = 0;
again:
	i++;
	if (i < n)
		goto again;
	return i;
}
int big(void)
{
	char buf[300];
	int i, s = 0;
	for (i = 0; i < 300; i++)
		buf[i] = i;
	for (i = 0; i < 300; i++)
		s += buf[i];
	return s;
}
int kr(a, b)
int a;
char *b;
{
	return a + b[0];
}
int main(int argc, char *argv[])
{
	if (sw(0) != 10 || sw(1) != 20 || sw(2) != 20 || sw(-1) != 30 || sw(1000) != 40 || sw(100) != 50 || sw(7) != 99)
		return 1;
	if (sw2(1) != 3 || sw2(2) != 2 || sw2(3) != 3 || sw2(4) != 0)
		return 2;
	if (GREEN != 5 || BLUE != 6)
		return 3;
	if (g(10) != 10)
		return 4;
	if (big() != 33586)
		return 5;
	if (kr(1, "A") != 66)
		return 6;
	return 0;
}
