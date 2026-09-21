#include <errno.h>
#include <libintl.h>
#include <stddef.h>

char* bindtextdomain(const char* domainname, const char* dirname) {
	static const char dir[] = "/";
	if (!domainname || !*domainname || (dirname && ((dirname[0] != '/') || dirname[1]))) {
		errno = EINVAL;
		return NULL;
	}
	return (char*) dir;
}
