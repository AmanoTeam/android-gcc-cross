#include <fenv.h>

#if defined(__arm__)

int fetestexcept(int __exceptions) {
	fexcept_t __fpscr;
	fegetenv(&__fpscr);
	return (__fpscr & __exceptions);
}

#elif defined(__mips__) && !defined(__LP64__)

int fetestexcept(int __exceptions) {
	fexcept_t __fcsr;
	fegetenv(&__fcsr);
	return (__fcsr & __exceptions & FE_ALL_EXCEPT);
}

#endif
