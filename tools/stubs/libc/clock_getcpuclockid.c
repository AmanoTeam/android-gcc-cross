#include <errno.h>
#include <time.h>

int clock_getcpuclockid(pid_t __pid, clockid_t* __clock) {
	int __saved_errno = errno;

	clockid_t __result = ~(clockid_t) __pid << 3;
	__result |= 2;
	__result &= ~(clockid_t) 4;

	if (clock_getres(__result, NULL) == -1) {
		errno = __saved_errno;
		return ESRCH;
	}

	errno = __saved_errno;
	*__clock = __result;
	return 0;
}
