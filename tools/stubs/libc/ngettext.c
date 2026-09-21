#include <libintl.h>

char* ngettext(const char* msgid1, const char* msgid2, unsigned long n) {
	return (char*) ((n == 1) ? msgid1 : msgid2);
}
