#include "threads_internal.h"

int thrd_detach(thrd_t __thrd) {
	return __bionic_thrd_error(pthread_detach(__thrd));
}
