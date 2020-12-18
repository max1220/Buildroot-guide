# Set up the cross compilation environment variables
# Needs to be called in the base directory!

export PROJECT_BASEDIR="$(pwd)"
export PROJECT_BUILDROOT="${PROJECT_BASEDIR}/buildroot-2020.08.1"

export PATH="${PROJECT_BUILDROOT}/output/host/bin:/usr/local/bin:/usr/bin:/bin"
export CFLAGS="-std=gnu99 -Wall -Wextra -Wpedantic --sysroot=${PROJECT_BUILDROOT}/output/host/x86_64-buildroot-linux-uclibc/sysroot/"
export PREFIX=${TARGET_DIR}/usr/local
export CC=x86_64-buildroot-linux-uclibc-gcc
