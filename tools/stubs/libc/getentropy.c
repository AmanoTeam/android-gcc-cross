#include <errno.h>
#include <fcntl.h>
#include <limits.h>
#include <unistd.h>

int getentropy(void* __buffer, size_t __buffer_size) {
	if (__buffer_size > GETENTROPY_MAX) {
		errno = EINVAL;
		return -1;
	}

	int __fd = open("/dev/urandom", O_RDONLY | O_CLOEXEC);
	if (__fd < 0) {
		return -1;
	}

	size_t __received = 0;
	char* __p = __buffer;
	while (__received < __buffer_size) {
		ssize_t __n = TEMP_FAILURE_RETRY(read(__fd, __p, __buffer_size - __received));
		if (__n < 0) {
			close(__fd);
			errno = EIO;
			return -1;
		}
		if (__n == 0) {
			break;
		}
		__received += __n;
		__p += __n;
	}

	close(__fd);

	if (__received < __buffer_size) {
		errno = EIO;
		return -1;
	}

	return 0;
}
