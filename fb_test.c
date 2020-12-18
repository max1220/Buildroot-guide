#include <sys/ioctl.h>
#include <sys/mman.h>
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
		printf("Can't open /dev/fb0!\n");
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

	printf("increase yres_virtual from %d to %d\n", vinfo.yres_virtual, vinfo.yres*2);
	vinfo.yres_virtual = vinfo.yres*2;
	if (ioctl (fb, FBIOPUT_VSCREENINFO, &vinfo)==-1) {
		printf("ioctl FBIOPUT_VSCREENINFO failed: %s\n", strerror(errno));
		//return 1;
	}
	printf("Got yres_virtual: %d\n ", vinfo.yres_virtual);


	printf("setting vinfo.yoffset(%d) to %d\n", vinfo.yoffset, vinfo.yres*2);
	vinfo.yoffset = vinfo.yres*2;
	if (ioctl (fb, FBIOPAN_DISPLAY, &vinfo)==-1) {
		printf("ioctl FBIOPAN_DISPLAY failed: %s\n", strerror(errno));
		//return 1;
	}
	if (ioctl (fb, FBIOPUT_VSCREENINFO, &vinfo)==-1) {
		printf("ioctl FBIOPUT_VSCREENINFO failed: %s\n", strerror(errno));
		//return 1;
	}

	printf("Re-getting vinfo...\n ");
	if (ioctl (fb, FBIOGET_VSCREENINFO, &vinfo)==-1) {
		printf("ioctl FBIOGET_VSCREENINFO failed: %s\n", strerror(errno));
		return 1;
	}
	printf("Got yres_virtual: %d\n ", vinfo.yres_virtual);
	printf("Got yoffset: %d\n ", vinfo.yoffset);


	printf("Testing FBIO_WAITFORVSYNC\n");
	if (ioctl(fb, FBIO_WAITFORVSYNC, &zero) == -1) {
		printf("ioctl FBIO_WAITFORVSYNC failed: %s\n", strerror(errno));
		//return 1;
	}

	printf("Testing mmap\n");
	size_t buf_len = vinfo.xres*vinfo.yres*(vinfo.bits_per_pixel/8);
	void* mem = mmap(0, buf_len, PROT_WRITE, MAP_SHARED, fb, 0);
	if (mem == MAP_FAILED) {
		printf("mmap failed: %s\n", strerror(errno));
		return 1;
	}

	return 0;
}
