#include <stdlib.h>

void srand(unsigned int __s) {
	srand48(__s);
}
