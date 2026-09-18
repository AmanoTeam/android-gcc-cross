#include "threads_internal.h"

int tss_set(tss_t __key, void* __value) {
	return __bionic_thrd_error(pthread_setspecific(__key, __value));
}
