int fact(int n) { return n <= 1 ? 1 : n * fact(n - 1); }
int fib(int n) { if (n < 2) return n; return fib(n - 1) + fib(n - 2); }
int div(int a, int b) { return a / b; }
int mod(int a, int b) { return a % b; }
unsigned udiv(unsigned a, unsigned b) { return a / b; }
int counter(void) { static int n; return ++n; }
int apply(int (*f)(int), int v) { return f(v); }
int twice(int x) { return 2 * x; }

int main(int argc, char *argv[])
{
	int a = 7, b = -3, c;
	unsigned u = 40000;
	char ch = 200;
	signed char sc = -5;
	int (*fp)(int) = twice;

	if (fact(7) != 5040)
		return 1;
	if (fib(15) != 610)
		return 2;
	if (div(7, -2) != -3 || mod(7, -2) != 1 || div(-7, 2) != -3 || mod(-7, 2) != -1)
		return 3;
	if (udiv(60000, 7) != 8571)
		return 4;
	if (a * b != -21 || a - b != 10 || (a & 3) != 3 || (a | 8) != 15 || (a ^ 1) != 6)
		return 5;
	if (!(b < a) || b > a || !(u > 30000) || !(b < 0))
		return 6;
	if (ch != 200 || ch + 1 != 201 || sc != -5 || sc + 10 != 5)
		return 7;
	c = 0;
	c += 5; c -= 2; c *= 4; c /= 3; c %= 3; c <<= 4; c >>= 1; c |= 1; c ^= 3; c &= 6;
	if (c != 2)
		return 8;
	if (counter() != 1 || counter() != 2 || counter() != 3)
		return 9;
	if (apply(twice, 21) != 42 || fp(5) != 10 || (*fp)(6) != 12)
		return 10;
	c = (a > 5) && (b < 0);
	if (c != 1 || ((a < 5) || (b > 0)))
		return 11;
	c = 0;
	do c++; while (c < 10);
	if (c != 10)
		return 12;
	c = 0;
	for (a = 0; a < 100; a++) {
		if (a == 50)
			break;
		if (a & 1)
			continue;
		c++;
	}
	if (c != 25)
		return 13;
	a = 1, b = 2;
	if (a + b != 3)
		return 14;
	ch = 255;
	ch++;
	if (ch != 0)
		return 15;
	a = 5;
	if (a++ != 5 || a != 6 || ++a != 7 || a-- != 7 || --a != 5)
		return 16;
	if (-a != -5 || ~a != -6 || !a != 0 || !!a != 1)
		return 17;
	return 0;
}
