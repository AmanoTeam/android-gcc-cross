#include "threads_internal.h"

int tss_create(tss_t* __key, tss_dtor_t __dtor) {
	return __bionic_thrd_error(pthread_key_create(__key, __dtor));
}
