#!/bin/bash

qemu-system-x86_64 \
-kernel buildroot-2020.08.1/output/images/bzImage \
-m 512M \
-serial stdio \
-vga std \
-append "quiet"
