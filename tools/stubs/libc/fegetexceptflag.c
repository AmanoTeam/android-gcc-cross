#include <fenv.h>

#if defined(__arm__)

int fegetexceptflag(fexcept_t* __flag_ptr, int __exceptions) {
	fexcept_t __fpscr;
	fegetenv(&__fpscr);
	*__flag_ptr = __fpscr & __exceptions;
	return 0;
}

#elif defined(__mips__) && !defined(__LP64__)

int fegetexceptflag(fexcept_t* __flag_ptr, int __exceptions) {
	fexcept_t __fcsr;
	fegetenv(&__fcsr);
	*__flag_ptr = __fcsr & __exceptions & FE_ALL_EXCEPT;
	return 0;
}

#endif
