#include <fenv.h>

#if defined(__arm__)

#define FPSCR_RMODE_SHIFT 22

int fesetround(int __rounding_mode) {
	fenv_t _fpscr;
	fegetenv(&_fpscr);
	_fpscr &= ~(0x3 << FPSCR_RMODE_SHIFT);
	_fpscr |= (__rounding_mode << FPSCR_RMODE_SHIFT);
	fesetenv(&_fpscr);
	return 0;
}

#elif defined(__mips__) && !defined(__LP64__)

#define FCSR_RMASK 0x3

int fesetround(int __rounding_mode) {
	fenv_t _fcsr;
	fegetenv(&_fcsr);
	_fcsr &= ~FCSR_RMASK;
	_fcsr |= (__rounding_mode & FCSR_RMASK);
	fesetenv(&_fcsr);
	return 0;
}

#endif
