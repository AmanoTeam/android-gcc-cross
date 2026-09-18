#include <errno.h>
#include <threads.h>
#include <time.h>

int thrd_sleep(const struct timespec* __duration, struct timespec* __remaining) {
	int __rc = nanosleep(__duration, __remaining);
	if (__rc == 0) return 0;
	return (errno == EINTR) ? -1 : -2;
}
