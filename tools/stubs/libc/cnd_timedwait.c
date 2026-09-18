#include "threads_internal.h"

int cnd_timedwait(cnd_t* __cond, mtx_t* __mutex, const struct timespec* __timeout) {
	return __bionic_thrd_error(pthread_cond_timedwait(__cond, __mutex, __timeout));
}
