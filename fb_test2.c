#include <sys/ioctl.h>
#include <sys/mman.h>
#include <fcntl.h>
#include <linux/types.h>
#include <linux/ioctl.h>
#include <linux/fb.h>
#include <errno.h>
#include <string.h>
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <time.h>

static const int NS_IN_S = 1000000000;

static int flip = 0;


static int fb_fd;

static void* mem;
static size_t mem_len;
static void* buf_a;
static void* buf_b;

static struct fb_fix_screeninfo finfo;
static struct fb_var_screeninfo vinfo;


#ifdef DOUBLEBUF_ACTIVATE_VBL
#define DOUBLEBUF_ACTIVATE FB_ACTIVATE_VBL
#else
#define DOUBLEBUF_ACTIVATE FB_ACTIVATE_NOW
#endif
#ifdef DOUBLEBUF_IOCTL_PAN
#define DOUBLEBUF_IOCTL FBIOPAN_DISPLAY
#else
#define DOUBLEBUF_IOCTL FBIOPUT_VSCREENINFO
#endif


static uint64_t get_us() {
	struct timespec t;
	if (clock_gettime(CLOCK_MONOTONIC_RAW, &t) == -1) {
		return 0;
	}
	return ((uint64_t)t.tv_sec*1000000)+((uint64_t)(((double)t.tv_nsec/NS_IN_S)*1000000));
}



// draw directly to the framebuffer memory
static void draw_simple() {
	if (flip) {
		memset(mem, 0xFF, mem_len);
	} else {
		memset(mem, 0, mem_len);
	}
}



// draw directly to the framebuffer memory, wait for vsync using FBIO_WAITFORVSYNC ioctl
static int zero = 0;
static void draw_vsync() {
	if (ioctl(fb_fd, FBIO_WAITFORVSYNC, &zero) == -1) {
		printf("ioctl FBIO_WAITFORVSYNC failed: %s\n", strerror(errno));
		return;
	}
	draw_simple();
}



// Copy buffer content to framebuffer(back buffering)
static void draw_backbuf() {
	if (flip) {
		memcpy(mem, buf_b, mem_len);
	} else {
		memcpy(mem, buf_a, mem_len);
	}
}


// Draw using double-buffering(swap buffers using ioctl)
static void draw_doublebuf() {
	if (flip) {
		vinfo.yoffset = vinfo.yres;
	} else {
		vinfo.yoffset = 0;
	}
	vinfo.activate = DOUBLEBUF_ACTIVATE;

	if (ioctl (fb_fd, DOUBLEBUF_IOCTL, &vinfo)==-1) {
		printf("ioctl DOUBLEBUF_IOCTL failed: %s\n", strerror(errno));
		return;
	}
}



int main() {
	printf("Starting at %ldus\n", get_us());
	#ifdef DO_SIMPLE
	printf("using draw_simple\n");
	#endif
	#ifdef DO_VSYNC
	printf("using draw_vsync\n");
	#endif
	#ifdef DO_BACKBUF
	printf("using draw_backbuf\n");
	#endif
	#ifdef DO_DOUBLEBUF
	printf("using draw_doublebuf\n");
	#endif

	fb_fd = open("/dev/fb0", O_RDWR);
	if (fb_fd<0) {
		printf("Can't open /dev/fb0!\n");
		return 1;
	}

	if (ioctl (fb_fd, FBIOGET_VSCREENINFO, &vinfo)==-1) {
		printf("ioctl FBIOGET_VSCREENINFO failed: %s\n", strerror(errno));
		return 1;
	}
	if (ioctl (fb_fd, FBIOGET_FSCREENINFO, &finfo)==-1) {
		printf("ioctl FBIOGET_FSCREENINFO failed: %s\n", strerror(errno));
		return 1;
	}
	printf("vinfo:\n");
	printf("\txres, yres: %d, %d\n ", vinfo.xres, vinfo.yres);
	printf("\txres_virtual, yres_virtual: %d, %d\n ", vinfo.xres_virtual, vinfo.yres_virtual);
	printf("\txoffset, yoffset: %d, %d\n\n", vinfo.xoffset, vinfo.yoffset);

	mem_len = vinfo.xres*vinfo.yres*(vinfo.bits_per_pixel/8);
	printf("Calculated visible buffer len: %ld\n", mem_len);

	#ifdef DO_DOUBLEBUF
	printf("Double-buffering, mapping %d\n", finfo.smem_len);
	mem = mmap(0, finfo.smem_len, PROT_WRITE, MAP_SHARED, fb_fd, 0);
	printf("Pre-filling buffers\n");
	memset(mem, 0xFF, finfo.smem_len);
	memset(mem, 0, mem_len);
	#else
	printf("mapping %ld\n", mem_len);
	mem = mmap(0, mem_len, PROT_WRITE, MAP_SHARED, fb_fd, 0);
	#endif
	if (mem == MAP_FAILED) {
		printf("mmap failed: %s\n", strerror(errno));
		return 1;
	}

	buf_a = malloc(mem_len);
	memset(buf_a, 0, mem_len);
	buf_b = malloc(mem_len);
	memset(buf_b, 0xFF, mem_len);

	printf("Entering main loop at %ldus\n", get_us());
	uint64_t last = get_us();
	while (1) {
		#ifdef DO_SIMPLE
		draw_simple();
		#endif
		#ifdef DO_VSYNC
		draw_vsync();
		#endif
		#ifdef DO_BACKBUF
		draw_backbuf();
		#endif
		#ifdef DO_DOUBLEBUF
		draw_doublebuf();
		#endif

		if (flip) {
			flip = 0;
		} else {
			flip = 1;
		}

		uint64_t now = get_us();
		uint64_t dt = now-last;
		last = now;
		printf("frame took %ldus (flip=%d)\n", dt, flip);
	}

	return 0;
}
