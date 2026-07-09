#include <stdlib.h>

long long strtoll_l(const char* __s, char** __end_ptr, int __base, locale_t __l) {
	return strtoll(__s, __end_ptr, __base);
}
