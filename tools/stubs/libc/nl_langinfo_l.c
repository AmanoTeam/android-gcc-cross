#include <langinfo.h>

char* nl_langinfo_l(nl_item item, locale_t l) {
	(void) l;
	return nl_langinfo(item);
}
