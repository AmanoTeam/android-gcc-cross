#include <errno.h>
#include <malloc.h>

int posix_memalign(void** __memptr, size_t __alignment, size_t __size) {
	*__memptr = memalign(__alignment, __size);
	if (*__memptr == NULL) {
		return ENOMEM;
	}
	return 0;
}
