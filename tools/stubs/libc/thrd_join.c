#include <stdint.h>
#include <threads.h>

int thrd_join(thrd_t __thrd, int* __result) {
	void* __pthread_result;
	if (pthread_join(__thrd, &__pthread_result) != 0) return thrd_error;
	if (__result) {
		*__result = (int) (intptr_t) __pthread_result;
	}
	return thrd_success;
}
