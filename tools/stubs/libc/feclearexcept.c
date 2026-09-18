#include <fenv.h>

#if defined(__arm__)

int feclearexcept(int __exceptions) {
	fexcept_t __fpscr;
	fegetenv(&__fpscr);
	__fpscr &= ~__exceptions;
	fesetenv(&__fpscr);
	return 0;
}

#elif defined(__mips__) && !defined(__LP64__)

#define FCSR_CAUSE_SHIFT 10

int feclearexcept(int __exceptions) {
	fexcept_t __fcsr;
	fegetenv(&__fcsr);
	__exceptions &= FE_ALL_EXCEPT;
	__fcsr &= ~(__exceptions | (__exceptions << FCSR_CAUSE_SHIFT));
	fesetenv(&__fcsr);
	return 0;
}

#endif
