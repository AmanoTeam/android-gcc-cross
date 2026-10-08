#pragma once

#include <threads.h>

#if !__BIONIC_AVAILABILITY_GUARD(21)
int pthread_mutex_timedlock(pthread_mutex_t* __mutex, const struct timespec* __timeout);
#endif

int __bionic_thrd_error(int __pthread_code);
