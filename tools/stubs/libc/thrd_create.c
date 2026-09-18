#include <pthread.h>
#include <stdint.h>
#include <stdlib.h>
#include <threads.h>

#include "threads_internal.h"

struct __bionic_thrd_data {
	thrd_start_t __func;
	void* __arg;
};

static void* __bionic_thrd_trampoline(void* __arg) {
	struct __bionic_thrd_data __data = *(struct __bionic_thrd_data*) __arg;
	free(__arg);
	int __result = __data.__func(__data.__arg);
	return (void*) (uintptr_t) __result;
}

int thrd_create(thrd_t* __thrd, thrd_start_t __function, void* __arg) {
	struct __bionic_thrd_data* __pthread_arg = malloc(sizeof(struct __bionic_thrd_data));
	__pthread_arg->__func = __function;
	__pthread_arg->__arg = __arg;
	int __result = __bionic_thrd_error(pthread_create(__thrd, NULL, __bionic_thrd_trampoline, __pthread_arg));
	if (__result != thrd_success) free(__pthread_arg);
	return __result;
}
