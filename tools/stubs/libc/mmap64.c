#include <stddef.h>
#include <errno.h>

#include <fcntl.h>
#include <unistd.h>
#include <sys/mman.h>
#include <sys/types.h>

#if !defined(PAGE_SIZE)
	#define PAGE_SIZE 4096
#endif

#if !defined(__BIONIC_ALIGN)
	#define __BIONIC_ALIGN(__value, __alignment) (((__value) + (__alignment)-1) & ~((__alignment)-1))
#endif

void* mmap64(void* __addr, size_t __size, int __prot, int __flags, int __fd, off64_t __offset) {
	
	const int __mmap2_shift = 12; /* 2**12 == 4096 */
	
	if (__offset < 0 || (__offset & ((1UL << __mmap2_shift) - 1)) != 0) {
		errno = EINVAL;
		return MAP_FAILED;
	}

	// prevent allocations large enough for `end - start` to overflow
	size_t __rounded = __BIONIC_ALIGN(__size, PAGE_SIZE);
	
	if (__rounded < __size || __rounded > PTRDIFF_MAX) {
		errno = ENOMEM;
		return MAP_FAILED;
	}

	extern void* __mmap2(void* __addr, size_t __size, int __prot, int __flags, int __fd, size_t __offset);
	
	return __mmap2(__addr, __size, __prot, __flags, __fd, __offset >> __mmap2_shift);
	
}
