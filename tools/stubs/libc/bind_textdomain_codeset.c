#include <errno.h>
#include <libintl.h>
#include <strings.h>

char* bind_textdomain_codeset(const char* domainname, const char* codeset) {
	if (!domainname || !*domainname || (codeset && strcasecmp(codeset, "UTF-8"))) {
		errno = EINVAL;
	}
	return NULL;
}
