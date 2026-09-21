#include <errno.h>
#include <libintl.h>
#include <string.h>

char* textdomain(const char* domainname) {
	static const char default_str[] = "messages";
	if (domainname && *domainname && strcmp(domainname, default_str)) {
		errno = EINVAL;
		return NULL;
	}
	return (char*) default_str;
}
