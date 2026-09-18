#include "threads_internal.h"

int mtx_init(mtx_t* __mutex, int __type) {
	int __pthread_type = (__type & mtx_recursive) ? PTHREAD_MUTEX_RECURSIVE
	                                             : PTHREAD_MUTEX_NORMAL;
	__type &= ~mtx_recursive;
	if (__type != mtx_plain && __type != mtx_timed) return thrd_error;

	pthread_mutexattr_t __attr;
	pthread_mutexattr_init(&__attr);
	pthread_mutexattr_settype(&__attr, __pthread_type);
	return __bionic_thrd_error(pthread_mutex_init(__mutex, &__attr));
}
