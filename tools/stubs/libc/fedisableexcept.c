#include <fenv.h>

#if defined(__arm__)

#define FPSCR_ENABLE_SHIFT 8

int fedisableexcept(int __exceptions) {
	fenv_t __old_fpscr, __new_fpscr;
	fegetenv(&__old_fpscr);
	__new_fpscr = __old_fpscr & ~((__exceptions & FE_ALL_EXCEPT) << FPSCR_ENABLE_SHIFT);
	fesetenv(&__new_fpscr);
	return ((__old_fpscr >> FPSCR_ENABLE_SHIFT) & FE_ALL_EXCEPT);
}

#elif defined(__mips__) && !defined(__LP64__)

#define FCSR_ENABLE_SHIFT 5

int fedisableexcept(int __exceptions) {
	fenv_t __old_fcsr, __new_fcsr;
	fegetenv(&__old_fcsr);
	__new_fcsr = __old_fcsr & ~((__exceptions & FE_ALL_EXCEPT) << FCSR_ENABLE_SHIFT);
	fesetenv(&__new_fcsr);
	return ((__old_fcsr >> FCSR_ENABLE_SHIFT) & FE_ALL_EXCEPT);
}

#endif
