# Set up the cross compilation environment variables
export PATH=/home/max/work/buildroot-2020.08.1/output/host/bin:/usr/local/bin:/usr/bin:/bin
export CFLAGS="-std=gnu99 -Wall -Wextra -Wpedantic --sysroot=/home/max/work/buildroot-2020.08.1/output/host/x86_64-buildroot-linux-uclibc/sysroot/"
export PREFIX=${TARGET_DIR}/usr/local

# Set up the lua-db makefile environment variables
export DRM_CFLAGS=$(pkg-config --cflags libdrm)
export DRM_LIBS=$(pkg-config --libs libdrm)
export LUA_CFLAGS=$(pkg-config --cflags luajit)
export LUA_LIBS=$(pkg-config --libs luajit)
export CC=x86_64-buildroot-linux-uclibc-gcc
export LDB_MODULES="core module_fb module_gfx module_drm"
