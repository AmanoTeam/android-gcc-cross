#include "threads_internal.h"

int mtx_timedlock(mtx_t* __mutex, const struct timespec* __timeout) {
	return __bionic_thrd_error(pthread_mutex_timedlock(__mutex, __timeout));
}
