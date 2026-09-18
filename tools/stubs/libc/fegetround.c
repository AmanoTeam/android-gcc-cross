#include <fenv.h>

#if defined(__arm__)

#define FPSCR_RMODE_SHIFT 22

int fegetround(void) {
	fenv_t _fpscr;
	fegetenv(&_fpscr);
	return ((_fpscr >> FPSCR_RMODE_SHIFT) & 0x3);
}

#elif defined(__mips__) && !defined(__LP64__)

#define FCSR_RMASK 0x3

int fegetround(void) {
	fenv_t _fcsr;
	fegetenv(&_fcsr);
	return (_fcsr & FCSR_RMASK);
}

#endif
