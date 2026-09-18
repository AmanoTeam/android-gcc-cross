#include "threads_internal.h"

int mtx_trylock(mtx_t* __mutex) {
	return __bionic_thrd_error(pthread_mutex_trylock(__mutex));
}
