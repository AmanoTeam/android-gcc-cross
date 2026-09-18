#include "threads_internal.h"

int cnd_init(cnd_t* __cond) {
	return __bionic_thrd_error(pthread_cond_init(__cond, NULL));
}
