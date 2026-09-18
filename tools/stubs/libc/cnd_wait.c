#include "threads_internal.h"

int cnd_wait(cnd_t* __cond, mtx_t* __mutex) {
	return __bionic_thrd_error(pthread_cond_wait(__cond, __mutex));
}
