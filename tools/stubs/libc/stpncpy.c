#include <string.h>
#include <sys/types.h>

char* stpncpy(char* __dst, const char* __src, size_t __n) {
	size_t __len = 0;
	while (__len < __n && __src[__len])
		__len++;
	memcpy(__dst, __src, __len);
	memset(__dst + __len, 0, __n - __len);
	return __dst + __len;
}
