#include <fenv.h>

#if defined(__arm__)

int feraiseexcept(int __exceptions) {
	fexcept_t __ex = __exceptions;
	fesetexceptflag(&__ex, __exceptions);
	return 0;
}

#elif defined(__mips__) && !defined(__LP64__)

#define FCSR_CAUSE_SHIFT 10

int feraiseexcept(int __exceptions) {
	fexcept_t __fcsr;
	fegetenv(&__fcsr);
	__exceptions &= FE_ALL_EXCEPT;
	__fcsr |= __exceptions | (__exceptions << FCSR_CAUSE_SHIFT);
	fesetenv(&__fcsr);
	return 0;
}

#endif
