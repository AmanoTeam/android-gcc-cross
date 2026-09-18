#include <stdint.h>
#include <threads.h>

void thrd_exit(int __result) {
	pthread_exit((void*) (uintptr_t) __result);
}
