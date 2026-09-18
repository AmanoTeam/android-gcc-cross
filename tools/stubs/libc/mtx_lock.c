#include "threads_internal.h"

int mtx_lock(mtx_t* __mutex) {
	return __bionic_thrd_error(pthread_mutex_lock(__mutex));
}
