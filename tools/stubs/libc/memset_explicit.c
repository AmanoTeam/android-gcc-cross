#include <sys/types.h>

void* memset_explicit(void* __dst, int __ch, size_t __n) {
	void* __result = __builtin_memset(__dst, __ch, __n);
	__asm__ __volatile__("" : : "r"(__dst) : "memory");
	return __result;
}
