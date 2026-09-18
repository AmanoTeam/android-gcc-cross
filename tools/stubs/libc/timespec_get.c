#include <time.h>

int timespec_get(struct timespec* __ts, int __base) {
	return (clock_gettime(__base - 1, __ts) != -1) ? __base : 0;
}
