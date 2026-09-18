#include <fenv.h>

#if defined(__arm__)

int fesetenv(const fenv_t* __env) {
	fenv_t _fpscr = *__env;
	__asm__ __volatile__("vmsr fpscr,%0" : : "ri" (_fpscr));
	return 0;
}

#elif defined(__mips__) && !defined(__LP64__)

int fesetenv(const fenv_t* __env) {
	fenv_t _fcsr = *__env;
#ifdef __mips_hard_float
	__asm__ __volatile__("ctc1 %0,$31" : : "r" (_fcsr));
#endif
	return 0;
}

#endif
