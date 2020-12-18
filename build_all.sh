# Set up the cross compilation envirioment variables for the buildroot toolchain
. ./cross_env.sh

# Convert all images to proper format
cd bootmenu/
#./convert_to_pxbuf.lua
cd ..


# Build simple C applicatons
#$CC ${DRM_CFLAGS} ${DRM_LIBS} drm_test.c -o drm_test
#$CC ${DRM_CFLAGS} ${DRM_LIBS} modeset.c -o modeset
#$CC fb_test.c -o fb_test
#$CC -D DO_VSYNC fb_test2.c -o fb_test2_vsync
#$CC -D DO_SIMPLE fb_test2.c -o fb_test2_simple
#$CC -D DO_BACKBUF fb_test2.c -o fb_test2_backbuf
#$CC -D DO_DOUBLEBUF -D DOUBLEBUF_ACTIVATE_VBL -D DOUBLEBUF_IOCTL_PAN fb_test2.c -o fb_test2_doublebuf_vbl_pan
#$CC -D DO_DOUBLEBUF -D DOUBLEBUF_ACTIVATE_VBL fb_test2.c -o fb_test2_doublebuf_vbl
#$CC -D DO_DOUBLEBUF -D DOUBLEBUF_IOCTL_PAN fb_test2.c -o fb_test2_doublebuf_pan
#$CC -D DO_DOUBLEBUF fb_test2.c -o fb_test2_doublebuf

# Build and install lua-db
rm -rf lua-db/
cp -r ../lua-db .
cd lua-db/
make clean
make build
cd ..
