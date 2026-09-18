/* Copyright (c) 2005-2020 The musl development team. MIT licensed (see submodules/musl/COPYING). */

long double nanl(const char* __kind) {
	return nan(__kind);
}
