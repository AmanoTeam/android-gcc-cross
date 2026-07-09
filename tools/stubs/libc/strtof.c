#include <stdlib.h>
#include <errno.h>
#include <float.h>
#include <math.h>

float strtof(const char* nptr, char** endptr) {
  double d = strtod(nptr, endptr);
  if (d > FLT_MAX) {
    errno = ERANGE;
    return __builtin_huge_valf();
  } else if (d < -FLT_MAX) {
    errno = ERANGE;
    return -__builtin_huge_valf();
  }
  return __BIONIC_CAST(static_cast, float, d);
}
