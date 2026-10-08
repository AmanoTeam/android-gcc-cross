/* Copyright (c) 2005-2020 The musl development team. MIT licensed (see submodules/musl/COPYING). */

#include <math.h>

long double lgammal_r(long double __x, int* __sign) {
	return lgamma_r(__x, __sign);
}
