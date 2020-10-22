#include <sys/ioctl.h>
#include <fcntl.h>
#include <linux/types.h>
#include <linux/ioctl.h>
#include <linux/fb.h>
#include <errno.h>
#include <string.h>
#include <stdio.h>

static int zero = 0;

int main() {
	int fb = open("/dev/fb0", O_RDWR);
	while(1) {
		if (ioctl(fb, FBIO_WAITFORVSYNC, &zero) == -1) {
			printf("fb ioctl failed: %s\n", strerror(errno));
			break;
		}
	}
}
