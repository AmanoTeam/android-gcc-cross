#include <errno.h>
#include <pthread.h>
#include <sys/syscall.h>
#include <sys/time.h>
#include <time.h>
#include <unistd.h>

#if !__BIONIC_AVAILABILITY_GUARD(21)

#define FIELD_MASK(shift, bits)            (((1 << (bits)) - 1) << (shift))
#define FIELD_TO_BITS(val, shift, bits)    (((val) & ((1 << (bits)) - 1)) << (shift))
#define FIELD_FROM_BITS(val, shift, bits)  (((val) >> (shift)) & ((1 << (bits)) - 1))

#define MUTEX_STATE_SHIFT                  0
#define MUTEX_STATE_LEN                    2
#define MUTEX_STATE_MASK                   FIELD_MASK(MUTEX_STATE_SHIFT, MUTEX_STATE_LEN)
#define MUTEX_STATE_BITS_UNLOCKED          FIELD_TO_BITS(0, MUTEX_STATE_SHIFT, MUTEX_STATE_LEN)
#define MUTEX_STATE_BITS_LOCKED_UNCONTENDED FIELD_TO_BITS(1, MUTEX_STATE_SHIFT, MUTEX_STATE_LEN)
#define MUTEX_STATE_BITS_LOCKED_CONTENDED FIELD_TO_BITS(2, MUTEX_STATE_SHIFT, MUTEX_STATE_LEN)
#define MUTEX_STATE_BITS_IS_LOCKED_UNCONTENDED(v) \
	(((v) & MUTEX_STATE_MASK) == MUTEX_STATE_BITS_LOCKED_UNCONTENDED)
#define MUTEX_STATE_BITS_IS_LOCKED_CONTENDED(v) \
	(((v) & MUTEX_STATE_MASK) == MUTEX_STATE_BITS_LOCKED_CONTENDED)
#define MUTEX_STATE_BITS_FLIP_CONTENTION(v) \
	((v) ^ (MUTEX_STATE_BITS_LOCKED_CONTENDED ^ MUTEX_STATE_BITS_LOCKED_UNCONTENDED))

#define MUTEX_COUNTER_SHIFT                2
#define MUTEX_COUNTER_LEN                  11
#define MUTEX_COUNTER_MASK                 FIELD_MASK(MUTEX_COUNTER_SHIFT, MUTEX_COUNTER_LEN)
#define MUTEX_COUNTER_BITS_WILL_OVERFLOW(v) (((v) & MUTEX_COUNTER_MASK) == MUTEX_COUNTER_MASK)
#define MUTEX_COUNTER_BITS_ONE             FIELD_TO_BITS(1, MUTEX_COUNTER_SHIFT, MUTEX_COUNTER_LEN)

#define MUTEX_SHARED_SHIFT                 13
#define MUTEX_SHARED_MASK                  FIELD_MASK(MUTEX_SHARED_SHIFT, 1)

#define MUTEX_TYPE_SHIFT                   14
#define MUTEX_TYPE_LEN                     2
#define MUTEX_TYPE_MASK                    FIELD_MASK(MUTEX_TYPE_SHIFT, MUTEX_TYPE_LEN)
#define MUTEX_TYPE_NORMAL                  0
#define MUTEX_TYPE_RECURSIVE               1
#define MUTEX_TYPE_ERRORCHECK              2
#define MUTEX_TYPE_BITS(t)                 FIELD_TO_BITS(t, MUTEX_TYPE_SHIFT, MUTEX_TYPE_LEN)

#define MUTEX_OWNER_SHIFT                  16
#define MUTEX_OWNER_LEN                    16

#define FUTEX_WAIT                         0
#define FUTEX_WAKE                         1
#define FUTEX_PRIVATE_FLAG                 128

static volatile int* __mutex_value(pthread_mutex_t* __mutex) {
	return (volatile int*)&__mutex->__private[0];
}

static __inline__ int __bionic_cmpxchg(volatile int* __value, int __expected, int __desired) {
	int __old = __expected;
	int __success = __atomic_compare_exchange_n(__value, &__old, __desired, 0,
	                                            __ATOMIC_SEQ_CST, __ATOMIC_SEQ_CST);
	return __success ? 0 : 1;
}

static __inline__ int __bionic_swap(volatile int* __value, int __v) {
	return __atomic_exchange_n(__value, __v, __ATOMIC_SEQ_CST);
}

static __inline__ void __bionic_membar(void) {
	__atomic_thread_fence(__ATOMIC_SEQ_CST);
}

static int __bionic_futex_wait(volatile int* __ftx, int __shared, int __value,
                               const struct timespec* __ts) {
	int __ret = (int)syscall(SYS_futex, (int*)__ftx,
	                         __shared ? FUTEX_WAIT : FUTEX_WAIT | FUTEX_PRIVATE_FLAG,
	                         __value, __ts, NULL, 0);
	if (__ret == -1) {
		return errno;
	}
	return 0;
}

static int check_timespec(const struct timespec* __ts) {
	if (__ts == NULL) {
		return EINVAL;
	}
	if (__ts->tv_sec < 0 || __ts->tv_nsec < 0 || __ts->tv_nsec >= 1000000000) {
		return EINVAL;
	}
	return 0;
}

static int __timespec_to_relative(struct timespec* __ts, const struct timespec* __abstime) {
	struct timeval __now;
	gettimeofday(&__now, NULL);
	__ts->tv_sec = __abstime->tv_sec - __now.tv_sec;
	__ts->tv_nsec = __abstime->tv_nsec - __now.tv_usec * 1000;
	if (__ts->tv_nsec < 0) {
		__ts->tv_sec--;
		__ts->tv_nsec += 1000000000;
	}
	if (__ts->tv_sec < 0) {
		return -1;
	}
	return 0;
}

static int __recursive_increment(volatile int* __value, int __mvalue, int __mtype) {
	int __newval;

	if (__mtype == MUTEX_TYPE_BITS(MUTEX_TYPE_ERRORCHECK)) {
		return EDEADLK;
	}

	if (MUTEX_COUNTER_BITS_WILL_OVERFLOW(__mvalue)) {
		return EAGAIN;
	}

	for (;;) {
		__newval = __mvalue + MUTEX_COUNTER_BITS_ONE;
		if (__predict_true(__bionic_cmpxchg(__value, __mvalue, __newval) == 0)) {
			return 0;
		}
		__mvalue = *__value;
	}
}

int pthread_mutex_timedlock(pthread_mutex_t* __mutex, const struct timespec* __timeout) {
	volatile int* __value;
	struct timespec __ts;
	int __mvalue, __mtype, __shared, __tid, __newval, __error;

	if (__predict_false(__mutex == NULL)) {
		return EINVAL;
	}

	__value = __mutex_value(__mutex);
	__mvalue = *__value;
	__mtype = __mvalue & MUTEX_TYPE_MASK;
	__shared = __mvalue & MUTEX_SHARED_MASK;

	if (__predict_true(__mtype == MUTEX_TYPE_BITS(MUTEX_TYPE_NORMAL))) {
		if (__bionic_cmpxchg(__value, __shared | MUTEX_STATE_BITS_UNLOCKED,
		                      __shared | MUTEX_STATE_BITS_LOCKED_UNCONTENDED) == 0) {
			__bionic_membar();
			return 0;
		}

		__error = check_timespec(__timeout);
		if (__error != 0) {
			return __error;
		}

		while (__bionic_swap(__value, __shared | MUTEX_STATE_BITS_LOCKED_CONTENDED) !=
		       (__shared | MUTEX_STATE_BITS_UNLOCKED)) {
			if (__timespec_to_relative(&__ts, __timeout) < 0) {
				return ETIMEDOUT;
			}
			__bionic_futex_wait(__value, __shared,
			                     __shared | MUTEX_STATE_BITS_LOCKED_CONTENDED, &__ts);
		}
		__bionic_membar();
		return 0;
	}

	__tid = (int)syscall(SYS_gettid);
	if (__tid == FIELD_FROM_BITS(__mvalue, MUTEX_OWNER_SHIFT, MUTEX_OWNER_LEN)) {
		return __recursive_increment(__value, __mvalue, __mtype);
	}

	__error = check_timespec(__timeout);
	if (__error != 0) {
		return __error;
	}

	__mtype |= __shared;

	if (__mvalue == __mtype) {
		__newval = FIELD_TO_BITS(__tid, MUTEX_OWNER_SHIFT, MUTEX_OWNER_LEN) | __mtype |
		           MUTEX_STATE_BITS_LOCKED_UNCONTENDED;
		if (__predict_true(__bionic_cmpxchg(__value, __mtype, __newval) == 0)) {
			__bionic_membar();
			return 0;
		}
		__mvalue = *__value;
	}

	for (;;) {
		if (__mvalue == __mtype) {
			__newval = FIELD_TO_BITS(__tid, MUTEX_OWNER_SHIFT, MUTEX_OWNER_LEN) | __mtype |
			           MUTEX_STATE_BITS_LOCKED_CONTENDED;
			if (__bionic_cmpxchg(__value, __mtype, __newval) == 0) {
				__bionic_membar();
				return 0;
			}
			if (__timespec_to_relative(&__ts, __timeout) < 0) {
				return ETIMEDOUT;
			}
			__mvalue = *__value;
			continue;
		}

		if (MUTEX_STATE_BITS_IS_LOCKED_UNCONTENDED(__mvalue)) {
			__newval = MUTEX_STATE_BITS_FLIP_CONTENTION(__mvalue);
			if (__bionic_cmpxchg(__value, __mvalue, __newval) != 0) {
				__mvalue = *__value;
			} else {
				__mvalue = __newval;
			}
		}

		if (__timespec_to_relative(&__ts, __timeout) < 0) {
			return ETIMEDOUT;
		}

		if (MUTEX_STATE_BITS_IS_LOCKED_CONTENDED(__mvalue)) {
			__bionic_futex_wait(__value, __shared, __mvalue, &__ts);
			__mvalue = *__value;
		}
	}
}
#endif
