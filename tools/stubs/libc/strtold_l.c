#include <stdlib.h>

long double strtold_l(const char* __s, char** __end_ptr, locale_t __l) {
	return strtold(__s, __end_ptr);
}
