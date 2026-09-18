#include <time.h>

int timespec_getres(struct timespec* __ts, int __base) {
	return (clock_getres(__base - 1, __ts) != -1) ? __base : 0;
}
