#include <fenv.h>

#if defined(__arm__)

#define FPSCR_ENABLE_SHIFT 8
#define FPSCR_ENABLE_MASK (FE_ALL_EXCEPT << FPSCR_ENABLE_SHIFT)

int fegetexcept(void) {
	fenv_t __fpscr;
	fegetenv(&__fpscr);
	return ((__fpscr & FPSCR_ENABLE_MASK) >> FPSCR_ENABLE_SHIFT);
}

#elif defined(__mips__) && !defined(__LP64__)

#define FCSR_ENABLE_SHIFT 5
#define FCSR_ENABLE_MASK (FE_ALL_EXCEPT << FCSR_ENABLE_SHIFT)

int fegetexcept(void) {
	fenv_t __fcsr;
	fegetenv(&__fcsr);
	return ((__fcsr & FCSR_ENABLE_MASK) >> FCSR_ENABLE_SHIFT);
}

#endif
