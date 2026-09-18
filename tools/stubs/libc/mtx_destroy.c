#include <threads.h>

void mtx_destroy(mtx_t* __mutex) {
	pthread_mutex_destroy(__mutex);
}
