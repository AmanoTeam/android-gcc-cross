#include <fenv.h>

#if defined(__arm__)

int fegetenv(fenv_t* __env) {
	fenv_t _fpscr;
	__asm__ __volatile__("vmrs %0,fpscr" : "=r" (_fpscr));
	*__env = _fpscr;
	return 0;
}

#elif defined(__mips__) && !defined(__LP64__)

int fegetenv(fenv_t* __env) {
	fenv_t _fcsr = 0;
#ifdef __mips_hard_float
	__asm__ __volatile__("cfc1 %0,$31" : "=r" (_fcsr));
#endif
	*__env = _fcsr;
	return 0;
}

#endif
