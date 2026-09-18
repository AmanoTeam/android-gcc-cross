#include <fenv.h>

#if defined(__arm__) || (defined(__mips__) && !defined(__LP64__))

const fenv_t __fe_dfl_env = {0};

#endif
