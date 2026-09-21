#include <libintl.h>

char* dcngettext(const char* domainname, const char* msgid1, const char* msgid2, unsigned long n, int category) {
	(void) domainname;
	(void) category;
	return (char*) ((n == 1) ? msgid1 : msgid2);
}
