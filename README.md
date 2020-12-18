# This repo

I'm working on a buildroot guide, and multiple buildroot-based systems.

Currently in this repo is a project called "bootmenu". It's a buildroot-
based minimal kernel+initramfs that will provide a graphical menu to load
other kernels via the kexec() mechanism.

I'm writing this as a guide for myself and others mostly as a starting point
for simple buildroot-based projects and hacks. It is intended as a copy-paste
source, with links to the proper buildroot documentation for reference.

It is assumed the reader is somewhat familiar with Linux.



# This version

This exact version of the repo contains a clean project directory, containing
only minimal, project-independent configuration. It's intended to be used as a
starting point for other projects.



# What is buildroot?

From the buildroot manual:

    Buildroot is a tool that simplifies and automates the process of building
    a complete Linux system for an embedded system, using cross-compilation.

As the name suggest, it's a compilation of makefiles and tools that make
compiling a cross-toolchain and a Linux userland based on that cross-toolchain
easy("build" a "root" filesystem).

It also supports a lot of other functions, like compiling a Linux kernel and combining it with and
initrd, generating .iso images, etc.

It is intended for embedded systems(e.g. OpenWRT is based on it), but because
it's very flexible, it can be used for almost anything(from embedded systems,
to lightweight application containers, and even fully-blown desktop systems).

There are a lot of packages in the buildroot build system. These packages
are build into the generated root filesystem. There is no runtime package
manager, unless provided by the user.



# What this tutorial covers

In this tutorial, we will use buildroot to build several example systems, and
boot them. This is not a reference for buildroot. It's intended as a
beginners-guide for people that want to use buildroot for a project or a hack
(using this tutorial as a copy-paste source is encouraged).

Basic familiarity with Linux and shell tools is assumed. No root privileges should be required.

The first system image we build is just the default buildroot configuration.
We will test it using proot, as it is not bootable.

The we will learn to customize the generated system a bit, by compiling in a
few extra packages, including a Linux kernel. We will use a buildroot
option to append the generated system as an initrd to the kernel.
The final image can be booted using QEMU's -kernel option, or on real hardware
using an grub2 entry.

Next, It will explain how to store project-specific configuration outside of
the buildroot tree, and show how to use an overlay directory and post-build
scripts to customize the generated image further. Also covered is using the
generated buildroot toolchain to compile projects not integrated into
buildroot(using my library lua-db as an example).

Last will be an overview of what we've covered by reviewing my project "bootmenu".
It's written in LuaJIT, and makes use of every feature covered here(This is
no accident; This guide was made in the process of creating the bootmenu project)



# Requirements
(TODO: get a list of debian/common distribution package names)

	build-essentials proot

See https://buildroot.org/downloads/manual/manual.html#requirement

You might want a reasonably fast multi-threaded CPU, lots of RAM, and a fast
SSD to speed up the build process if you're adding copious amounts of extra
packages.



# Preparation

First order of business is preparation. Let's create a directory for this
tutorial, and download a buildroot release tarball into it. I'll be using the
latest stable release as of the release date of this tutorial(buildroot 2020.08.1).

    mkdir ~/work
    cd ~/work
    wget https://buildroot.org/downloads/buildroot-2020.08.1.tar.gz
    tar -xvf buildroot-2020.08.1.tar.gz

We're ready now to configure and build our first buildroot system!



# First system

## Configuration

We can start configuring a simple system right now. Buildroot uses a
Kconfig-based system for configuration like the Linux kernel. If you're familiar
with building the Linux kernel, the graphical configuration interface should
be familiar:

    cd ~/work/buildroot-2020.08.1/
    make menuconfig

This will open the ncurses-based configuration menu.

You can navigate the menu using the arrow keys, enter and escape.
For now, we will just change `Target Options -> Target Architecture` to x86_64.

Make sure to save your changes when exiting(use the escape key until
you're asked to save changes, then press enter).

And that's it. We're ready for compilation now!


## Build

Now follows the process of compiling the buildroot sources into a system image.
Fortunately, buildroot makes this super easy:

	cd ~/work/buildroot-2020.08.1/
    time make

This will start building a cross-toolchain, then use that cross-toolchain to
compile all default buildroot packages(busybox, etc.), and include them in the
generated system image(in this case, a .tar that contains the root file system).

On my system(Ryzen 2600, 16GB RAM, generic SSD) this took about 10 minutes.

The generated tarball is in `~/work/buildroot-2020.08.1/output/images`.
For me, it was about 2MB in size.



### Top-level parallel builds

*Do not specify a top-level parallel build option like `-jN`!*

Buildroot does not currently support top-level parallel builds!
(It's experimental and requires configuration, see:
https://buildroot.org/downloads/manual/manual.html#top-level-parallel-build)



## Testing

We only have a .tar right now, and that is not bootable. We can test it using
proot. proot is a tool that allows you to pretend to Linux programs that you
have a different root filesystem than you actually have(Like chroot or fakeroot,
but does not require root). It can also pretend you're root, even when you're
not(It overloads functions like open() using the dynamic linker).

	mkdir ~/work/proot
	cd ~/work/proot
	cp ../buildroot-2020.08.1/output/images/rootfs.tar .
	proot -0 tar xpvf rootfs.tar --xattrs-include='*.*' --numeric-owner
	proot -S .

You're now in a buildroot-based shell! This system does not even use your system
LibC. Let's explore the generated filesystem a little:

(TODO: write filesystem exploration)
.. so the filesystem is composed of:

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
