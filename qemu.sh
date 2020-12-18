#!/bin/bash

# Set up the cross compilation envirioment variables for the buildroot toolchain
# Needed for export path
. ./cross_env.sh

qemu-system-x86_64 \
-kernel ${PROJECT_BUILDROOT}/output/images/bzImage \
-m 512M \
-serial stdio \
-vga std \
-append "quiet"
