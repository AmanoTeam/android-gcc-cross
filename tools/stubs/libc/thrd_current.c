#include <threads.h>

thrd_t thrd_current(void) {
	return pthread_self();
}
