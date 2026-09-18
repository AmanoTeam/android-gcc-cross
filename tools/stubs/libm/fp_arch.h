/*
 * Android/bionic adaptation of musl's arch/generic/fp_arch.h (which is
 * empty): pulls in <features.h> so verbatim musl sources get the hidden
 * macro, and supplies the __BYTE_ORDER defines that bionic's <endian.h>
 * does not export.  Every Android ABI is little-endian.
 */

#include <features.h>

#ifndef __LITTLE_ENDIAN
#define __LITTLE_ENDIAN 1234
#define __BIG_ENDIAN 4321
#define __PDP_ENDIAN 3412
#endif

#ifndef __BYTE_ORDER
#define __BYTE_ORDER __LITTLE_ENDIAN
#endif
