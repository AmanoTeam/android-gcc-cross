#include <sys/types.h>

void* mempcpy(void* __dst, const void* __src, size_t __n) {
	return __builtin_mempcpy(__dst, __src, __n);
}
