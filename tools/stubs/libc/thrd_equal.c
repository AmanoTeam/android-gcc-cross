#include <threads.h>

int thrd_equal(thrd_t __lhs, thrd_t __rhs) {
	return pthread_equal(__lhs, __rhs);
}
