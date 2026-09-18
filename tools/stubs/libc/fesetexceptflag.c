#include <fenv.h>

#if defined(__arm__)

int fesetexceptflag(const fexcept_t* __flag_ptr, int __exceptions) {
	fexcept_t __fpscr;
	fegetenv(&__fpscr);
	__fpscr &= ~__exceptions;
	__fpscr |= *__flag_ptr & __exceptions;
	fesetenv(&__fpscr);
	return 0;
}

#elif defined(__mips__) && !defined(__LP64__)

int fesetexceptflag(const fexcept_t* __flag_ptr, int __exceptions) {
	fexcept_t __fcsr;
	fegetenv(&__fcsr);
	__exceptions &= FE_ALL_EXCEPT;
	__fcsr &= ~__exceptions;
	__fcsr |= *__flag_ptr & __exceptions;
	fesetenv(&__fcsr);
	return 0;
}

#endif
