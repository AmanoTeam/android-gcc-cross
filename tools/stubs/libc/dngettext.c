#include <libintl.h>

char* dngettext(const char* domainname, const char* msgid1, const char* msgid2, unsigned long n) {
	(void) domainname;
	return (char*) ((n == 1) ? msgid1 : msgid2);
}
