#include <sys/ioctl.h>
#include <linux/termios.h>

int tcsetwinsize(int __fd, const struct winsize* __size) {
	return ioctl(__fd, TIOCSWINSZ, __size);
}
