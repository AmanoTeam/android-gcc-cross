#include <stdlib.h>
#include <sys/system_properties.h>

int android_get_device_api_level(void) {
	int api_level = 0;
	char value[92] = {0};

	if (__system_property_get("ro.build.version.sdk", value) < 1) {
		return -1;
	}

	api_level = atoi(value);

	return (api_level > 0) ? api_level : -1;
}
