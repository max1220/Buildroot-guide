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
	struct fb_fix_screeninfo finfo;
	struct fb_var_screeninfo vinfo;

	int fb = open("/dev/fb0", O_RDWR);
	if (fb<0) {
		printf("Can't open framebuffer!\n");
		return 1;
	}

	if (ioctl (fb, FBIOGET_VSCREENINFO, &vinfo)==-1) {
		printf("ioctl FBIOGET_VSCREENINFO failed: %s\n", strerror(errno));
		return 1;
	}
	if (ioctl (fb, FBIOGET_FSCREENINFO, &finfo)==-1) {
		printf("ioctl FBIOGET_FSCREENINFO failed: %s\n", strerror(errno));
		return 1;
	}

	vinfo.yoffset = 200;

	if (ioctl (fb, FBIOPAN_DISPLAY, &vinfo)==-1) {
		printf("ioctl FBIOPAN_DISPLAY failed: %s\n", strerror(errno));
		//return 1;
	}
	if (ioctl (fb, FBIOPUT_VSCREENINFO, &vinfo)==-1) {
		printf("ioctl FBIOPUT_VSCREENINFO failed: %s\n", strerror(errno));
		return 1;
	}
	printf("Re-getting vinfo...\n ");
	if (ioctl (fb, FBIOGET_VSCREENINFO, &vinfo)==-1) {
		printf("ioctl FBIOGET_VSCREENINFO failed: %s\n", strerror(errno));
		return 1;
	}
	printf("Got yoffset: %d\n ", vinfo.yoffset);


	return 0;
	/*
	// map twice the memory needed for double-buffering
	size_t buf_len = vinfo.xres*vinfo.yres*(vinfo.bytes_per_pixel/8);
	void* buf_a = mmap(0, buf_len * 2, PROT_WRITE, MAP_SHARED, fb, 0);
	void* buf_b = buf_a + buf_len;

	for (int i=0; i<100; i++) {
		buf_a[i*4] = 255;
		buf_b[i*4+1] = 255;
	}

	int flip = 0;

	while(1) {
		if (flip) {

			flip = 0;
		} else {
			flip = 1;
		}

		if (ioctl(fb, FBIO_WAITFORVSYNC, &zero) == -1) {
			printf("ioctl FBIO_WAITFORVSYNC failed: %s\n", strerror(errno));
			return 1;
		}
	}
	*/
}
