#include "threads_internal.h"

int mtx_unlock(mtx_t* __mutex) {
	return __bionic_thrd_error(pthread_mutex_unlock(__mutex));
}
