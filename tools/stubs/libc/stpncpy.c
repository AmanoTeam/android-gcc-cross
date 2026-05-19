#include <sys/types.h>

char* stpncpy(char* __dst, const char* __src, size_t __n) {
	return __builtin_stpncpy(__dst, __src, __n);
}
