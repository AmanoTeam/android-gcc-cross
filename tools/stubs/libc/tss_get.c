#include <threads.h>

void* tss_get(tss_t __key) {
	return pthread_getspecific(__key);
}
