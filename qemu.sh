#!/bin/bash

qemu-system-x86_64 \
-kernel buildroot-2020.08.1/output/images/bzImage \
-m 128M \
-vga qxl \
-append "quiet vga=0x315"
