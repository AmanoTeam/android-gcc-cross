#include <stdlib.h>

int grantpt(int __fd __attribute((unused))) {
  return 0; /* devpts does this all for us! */
}
