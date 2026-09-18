#include <threads.h>

void tss_delete(tss_t __key) {
	pthread_key_delete(__key);
}
