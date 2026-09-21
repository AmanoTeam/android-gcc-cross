#include <libintl.h>

char* dgettext(const char* domainname, const char* msgid) {
	(void) domainname;
	return (char*) msgid;
}
