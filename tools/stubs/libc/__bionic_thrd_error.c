#include <errno.h>

#include "threads_internal.h"

int __bionic_thrd_error(int __pthread_code) {
	switch (__pthread_code) {
		case 0: return 0;
		case ENOMEM: return thrd_nomem;
		case ETIMEDOUT: return thrd_timedout;
		case EBUSY: return thrd_busy;
		default: return thrd_error;
	}
}
