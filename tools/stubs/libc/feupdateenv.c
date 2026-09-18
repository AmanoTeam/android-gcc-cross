#include <fenv.h>

#if defined(__arm__)

int feupdateenv(const fenv_t* __env) {
	fexcept_t __fpscr;
	fegetenv(&__fpscr);
	fesetenv(__env);
	feraiseexcept(__fpscr & FE_ALL_EXCEPT);
	return 0;
}

#elif defined(__mips__) && !defined(__LP64__)

int feupdateenv(const fenv_t* __env) {
	fexcept_t __fcsr;
	fegetenv(&__fcsr);
	fesetenv(__env);
	feraiseexcept(__fcsr & FE_ALL_EXCEPT);
	return 0;
}

#endif
