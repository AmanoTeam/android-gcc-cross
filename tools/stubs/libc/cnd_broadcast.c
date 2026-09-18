#include "threads_internal.h"

int cnd_broadcast(cnd_t* __cond) {
	return __bionic_thrd_error(pthread_cond_broadcast(__cond));
}
