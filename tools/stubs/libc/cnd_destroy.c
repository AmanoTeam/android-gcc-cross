#include <threads.h>

void cnd_destroy(cnd_t* __cond) {
	pthread_cond_destroy(__cond);
}
