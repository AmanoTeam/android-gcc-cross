#include <stdlib.h>

long double strtold(const char* __s, char** __end_ptr) {
	return strtod(__s, __end_ptr);
}
