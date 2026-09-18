/* Copyright (c) 2005-2020 The musl development team. MIT licensed (see submodules/musl/COPYING). */

long double modfl(long double __x, long double* __integral_part) {
	double __d;
	long double __r = modf((double) __x, &__d);
	*__integral_part = __d;
	return __r;
}
