# This repo

I'm working on a buildroot guide, and multiple buildroot-based systems.
One of the is the system I planned for the L1T devember
(https://forum.level1techs.com/t/lua-libraries-for-crazy-bootable-devember-challenge/162399/3).
While that project won't be in this directory, this repo is intended as a starting point for it.

Tho other buildroot-system I planned is a simple graphical "bootloader"
that uses the `kexec()`-facilities to boot another Linux kernel.
That is currently in this repo, mostly in the `rootfs_overlay/usr/bootmenu` directory.

In the future, this repo will be split into the seperate `bootmenu` part, and
the buildroot guide.

I'd still be glad for every spelling mistake etc. you can find, I'm not a native
speaker.



# Buildroot basic guide

# What is buildroot?

From the buildroot manual:

    Buildroot is a tool that simplifies and automates the process of building
    a complete Linux system for an embedded system, using cross-compilation.

In other words: Buildroot is software that compiles a lot of software into a
system image. Buildroot also can use or even generate a cross compilation
toolchain, and build for foreign architectures(cross-compilation).
That is most useful for embedded systems, but can also be used for desktop
systems, because nowadays buildroot has a lot of support for desktop/server
systems(they make great light-weight containers).

Keep in mind however that buildroot has no run-time package support. While
buildroot has a notion of "packets" at compile-time, the generated image has
no package manager or package metadata etc. installed(unless provided externally).



# What this tutorial explains

First, we will use buildroot to generate a more or less default filesystem image.
We show that filesystem image booting in QEMU.
Then we'll add compiling a kernel to our configuration, learn about configuring
that kernel(including integrating the kernel configuration properly into the
buildroot build system), and append an initrd to the kernel for an
all-in-one bootable kernel image. We'll also show using buildroot to generate
and .iso image that uses grub to boot the generated image.
We will add an external filesystem overlay, and also use the generated and
exported buildroot toolchain to cross-compile a simple C hello world on the host,
and store the generated binary in the filesystem overlay.
All configuration data will be stores separately.

As a final example, I will walk you through a simple application of this:
I will build a simple kexec-based graphical "bootloader".

This tutorial is not intended as a reference for buildroot. Buildroot has an
excellent manual(https://buildroot.org/downloads/manual/manual.html),
and I'm not experienced enough to even do that.
It's intended to be a beginners getting-started guide, and maybe a good
copy-paste command source.



# Requirements
(TODO: get a list of debian/common distribution package names)

See https://buildroot.org/downloads/manual/manual.html#requirement



# First steps

After installing the requirements, download a buildroot release and extract it
to a directory. For this tutorial, we'll create the directory `~/work`, and
download buildroot there:

    mkdir ~/work
    cd ~/work
    wget https://buildroot.org/downloads/buildroot-2020.08.1.tar.gz
    tar -xvf buildroot-2020.08.1.tar.gz

We can start configuring a simple system right now:

    cd buildroot-2020.08.1/
    make menuconfig

This will open the ncurses-based configuration menu.
For now, just change `Target Options -> Target Architecture` to x86_64.
You can navigate the menu using the arrow keys, enter and escape.
Make sure to save your changes when exiting.

We're ready for compiling now.



## First build

It's as easy as running:

    make

In the `~/work/buildroot-2020.08.1/` directory.
On my system(Ryzen 2600, 16GB RAM, generic SSD) this took about 10 minutes.

*Do not specify a top-level parallel build option like `-jN`!*
Buildroot does not yet support top-level parallel builds!
(It's experimental and requires configuration, see:
https://buildroot.org/downloads/manual/manual.html#top-level-parallel-build)

This will first build a GCC-based toolchain for compiling for the target
architecture(In this case x86_64), then build a basic filesystem image
by building the basic packages using the new toolchain. This includes a
libc(By default this is uclibc. That's one of the reasons buildroot always
builds a toolchain, even for x86_64).

Also included is busybox, a minimal implementation of the common system
utilities(ls, grep, etc.). It's way smaller than the standard coreutils.

The filesystem should now be composed of:

 * The target root skeleton
   * This includes static default configuration for the busybox-based system
     * `/etc/init.d` etc.
 * Generated configuration files
   * Some options in the buildroot config can generate files in the
     generated filesystem
     * `/etc/passwd` etc.
 * All compiled binaries from buildroot packages
   * This would include busybox, plus any other packages you select.
     * basically everything in `/bin`, `/usr/bin`, `/usr/lib` etc.

The generated filesystem in the default image is a tarball at:

    ~/work/buildroot-2020.08.1/output/images/rootfs.tar

For me, that tarball was about 2MB in the default configuration.



## Saving Buildroot configuration

The best way to store the buildroot configuration is to export it using

	make savedefconfig

This would store a config file in `~/work/buildroot-2020.08.1/defconfig`.

You can select where that config in

	Build Options -> Location to save buildroot config

I set it to `$(CONFIG_DIR)/../buildroot-config`, to store the configuration
file at `~/work/buildroot-2020.08.1/buildroot-config`.

You should run `make savedefconfig` every time you change the buildroot
configuration(e.g. after running `make menuconfig`).



## Test the generated system using proot

As a non-root alternative to chroot, you can use proot to test:

    mkdir ~/work/chroot
    cd ~/work/chroot
    cp ../buildroot-2020.08.1/output/images/rootfs.tar .
    proot -0 tar xpvf rootfs.tar --xattrs-include='*.*' --numeric-owner
	proot -S .

You're now in a buildroot proot container.



# Getting a bootable system, v1

You might have noticed that so far, we've only generated a .tar ball.
To properly "boot" a Linux system, you need 3 things:

    * A Linux kernel
    * A userland
    * A Bootloader

So far, we've only provided the userland. But buildroot can help with all 3.
So let's enable some more options.

    Enable "Kernel -> Linux Kernel"
    Set "Kernel -> Kernel configuration" to "Use the architecture default configuration"
    Enable "Filesystem images -> initial RAM filesystem linked into linux kernel"

This will tell buildroot to build a kernel(using the default defconfig for
the specified architecture), and to generate an CPIO archive, linked to the
kernel image. After running

    make

There should now be a lot of new files in `~/work/buildroot-2020.08.1/output/images/`:

	images$ ls -lh
	total 14M
	-rw-r--r-- 1 max max 9.2M Oct 19 07:15 bzImage
	-rw-r--r-- 1 max max 1.7M Oct 19 07:15 rootfs.cpio
	-rw-r--r-- 1 max max 2.3M Oct 19 07:15 rootfs.tar

We can now easily boot the entire system in QEMU, for example:

	qemu-system-x86_64 -m 64M -kernel ~/work/buildroot-2020.08.1/output/images/bzImage

This works because out initrd that contains the generated filesystem is
already appended to the kernel. You could also load this file in grub easily.



## Getting a smaller bootable system

As you can see, the size of the kernel+initrd is quite large(9MB).

We can do better though: For example, currently the initrd uses no compression.
We also just build a kernel with all common modules for x86.
Compression for the initrd can be enabled in

	Filesystem images -> cpio the root filesystem -> Compression method

To further reduce the size, we need to configure the kernel image



# Modifying Kernel Configuration

You can enter the Linux kernel configuration menu like this:

	make linux-menuconfig

To use it in the buildroot build process, configure a custom kernel config:

	make menuconfig
	Set Kernel -> Kernel configuration to "Using a custom (def)config file"
	Set Kernel -> Configuration file path to "../kernel_config"

Then run

	make linux-update-defconfig

That should have exported your the kernel config to `~/work/kernel_config`.
This ensures that the kernel config is not lost when running `make clean`, for
for example. You need to do this after every change to the Linux kernel
configuration.

You can now rebuild the image.
After some basic optimizations, one can easily get the entire bootable system
down to about 6MB:

	-rw-r--r-- 1 max max 5.2M Oct 19 10:48 bzImage

It also uses less RAM at runtime, because I've disabled a lot of unneeded
kernel modules(Networking, Loadable modules, etc).



# Including files in the image

In general, there are four options to customize files in the generated system image.
You can create a buildroot package, create an overlay directory, or include it in
the target skeleton, or add it in a post-build script. What option you choose
depends on your use case, so I'll explain when each option is applicable.



## 1. Create a buildroot package

(TODO: Get link to documentation regarding packages, show example)
This is not covered here. See the buildroot documentation.

You should use this for regular compiled applications. Using the buildroot
build system is easy and ensures that your compiled program is compatible with
the generated system image(Compiled for the correct architecture, using the
correct libc, correct compiled-in paths, etc.).

This is always the cleanest option, and is very little effort for simple
libraries, but might be more involved for projects with e.g. complex dependencies,
and is not the right place for configuration data.



## 2. Create a target skeleton

This is not covered here. If you want to completely customize the filesystem
layout, you can overwrite the default target skeleton.

The target skeleton the first directory buildroot includes in the target file
system. All packages are installed on top of these files. Also includes
`/etc/init.d/*`, `/etc/passwd` etc.

A custom target skeleton also means that you won't be able to use
buildroot's menuconfig to configure things like users and getty.

You'd typically use this if you have a custom init system or equally strange
configurations.



## 3. Using a post-build script

TODO: Show common operations in an example script
You can specify the BR2_ROOTFS_POST_BUILD_SCRIPT option(In the menu as
`System configuration -> Custom scripts to run before creating filesystem images`),
or the BR2_ROOTFS_POST_FAKEROOT_SCRIPT option(In the menu as
`System configuration -> Custom scripts to run inside the fakeroot environment`)

This is not covered here. These scripts are called after the build process is completed, but before the
output filesystem images are created. You can modify the current filesystem
here.

This is especially useful for deleting files. BR2_ROOTFS_POST_FAKEROOT_SCRIPT
is called in the fakeroot environment, allowing e.g. to create device nodes
or correct filesystem permissions.

See the buildroot documentation on envirioment variables, etc.



## 4. Create an overlay

You can specify an overlay directory. This directory is copied over the
completed filesystem after building all packages. This makes it easy to
e.g. include pre-compiled applications in the generated image.

If you can compile your application externally so that it runs on the generated
system(architecture, libc, etc.), you can use this to include it.

This is also a good place for configuration file overrides and generic data.
As this is the most generic and simple solution, I will focus on this.

You can specify a list of overlays via the `BR2_ROOTFS_OVERLAY` variable(in the menu as
`System configuration -> Root filesystem overlay directories`).



# Including a custom keymap using an overlay

As you maybe can tell, I'm not a native english speaker. A lot of languages have
special keyboard requirements, and so does german. I will use this do demonstrate
how to include a file using an overlay.

Let's create a directory for the overlay:

	cd ~/work/
	mkdir rootfs_overlay

Enter the buildroot direcotry, set BR2_ROOTFS_OVERLAY to `../rootfs_overlay`

	cd buildroot-2020.08.1/
	make menuconfig # set BR2_ROOTFS_OVERLAY to `../rootfs_overlay`
	cd ..

Now, let's include a file

	# generate the keymap file
	mkdir -p rootfs_overlay/usr/share/keymaps
	loadkeys -b de-latin1 > rootfs_overlay/usr/share/keymaps/de-latin1.kmap

Let's also add an init script to load that keymap on boot:

	mkdir -p rootfs_overlay/etc/init.d/
	echo 'echo "Loading german keymap..."' >> rootfs_overlay/etc/init.d/110-kmap-de.sh
	echo "loadkmap < /usr/share/keymaps/de-latin1.kmap" >> rootfs_overlay/etc/init.d/110-kmap-de.sh
	chmod u+x rootfs_overlay/etc/init.d/110-kmap-de.sh

That should be enought to set the keyboard layout at boot.



# Compiling a simple C application using the buildroot toolchain

Now that you can include almost all files, you might want to know how to use
the buildroot toolchain: We've already covered that buildroot builds
it's own GCC-based toolchain for compiling the buildroot packages.
But what if you wanted to compile something that is not a buildroot package?
You can use the buildroot toolchain externally. There are two options available:



### let buildroot export the toolchain as a .tar archive

This is the cleanest option. You could even distribute that .tar to other people,
so they could compile programs for your platform.

	make sdk

This will basically put everything in `output/host` into a tarball.
Also included is a script to relocate the toolchain(it contains some hardcoded paths).
See the buildroot documentation for details. This is not explicitly covered here,
because we will use the `output/host` directory directly.



### Use the toolchain in the `output/host` directory

The directory `output/host` is where buildroot stores it's toolchain, and
related files by default(For example, C headers for all available libraries!)

For the most basic example programs, this is often enough:

	cd output/host/bin
	export PATH=$PATH:$PWD
	cd ../../..

You can now compile something using the tools in that folder(For example,
using `x86_64-linux-gcc`).

For slightly more complicated programs, you can use pkg-config to get the
build flags/includes needed for accessing buildroot library headers/
objects. The `--sysroot=` option comes in handy.
