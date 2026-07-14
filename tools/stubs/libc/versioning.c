#include <android/api-level.h>

static int DEVICE_API_LEVEL = 0;

int __isOSVersionAtLeast(int major, int minor __attribute__((unused)), int patch __attribute__((unused))) {
	DEVICE_API_LEVEL = android_get_device_api_level();
	return DEVICE_API_LEVEL >= major;
}
