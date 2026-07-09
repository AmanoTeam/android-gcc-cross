#include <stdlib.h>

void srandom(unsigned int __s) {
	srand48(__s);
}
