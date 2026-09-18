#include <sys/ioctl.h>
#include <linux/termios.h>

int tcgetwinsize(int __fd, struct winsize* __size) {
	return ioctl(__fd, TIOCGWINSZ, __size);
}
