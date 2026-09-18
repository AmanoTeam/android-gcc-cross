#include <fenv.h>

#if defined(__arm__)

#define FPSCR_ENABLE_SHIFT 8
#define FPSCR_ENABLE_MASK (FE_ALL_EXCEPT << FPSCR_ENABLE_SHIFT)

int feholdexcept(fenv_t* __env) {
	fenv_t __fpscr;
	fegetenv(&__fpscr);
	*__env = __fpscr;
	__fpscr &= ~(FE_ALL_EXCEPT | FPSCR_ENABLE_MASK);
	fesetenv(&__fpscr);
	return 0;
}

#elif defined(__mips__) && !defined(__LP64__)

#define FCSR_ENABLE_SHIFT 5
#define FCSR_ENABLE_MASK (FE_ALL_EXCEPT << FCSR_ENABLE_SHIFT)

int feholdexcept(fenv_t* __env) {
	fenv_t __fcsr;
	fegetenv(&__fcsr);
	*__env = __fcsr;
	__fcsr &= ~(FE_ALL_EXCEPT | FCSR_ENABLE_MASK);
	fesetenv(&__fcsr);
	return 0;
}

#endif
