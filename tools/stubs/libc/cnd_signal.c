#include "threads_internal.h"

int cnd_signal(cnd_t* __cond) {
	return __bionic_thrd_error(pthread_cond_signal(__cond));
}
