ROOTDIR := $(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))

BUILDDIR   = $(ROOTDIR)/build
CONFDIR    = $(ROOTDIR)/conf
KERNELDIR  = $(ROOTDIR)/src/linux
BBDIR      = $(ROOTDIR)/src/busybox
DESTDIR    = $(BUILDDIR)/rootfs

KERNEL           = $(BUILDDIR)/linux/arch/x86/boot/bzImage
KERNEL_DEFCONFIG = $(CONFDIR)/linux.defconfig

BUSYBOX          = $(BUILDDIR)/busybox/busybox
BB_DEFCONFIG     = $(CONFDIR)/busybox.defconfig

INITRAMFS  = $(BUILDDIR)/initramfs.cpio
INIT       = $(ROOTDIR)/src/init.sh

$(KERNEL): $(KERNEL_DEFCONFIG) $(INITRAMFS)
	cp $(KERNEL_DEFCONFIG) $(KERNELDIR)/arch/x86/configs/posix_defconfig
	$(MAKE) -C $(KERNELDIR) O=$(BUILDDIR)/linux posix_defconfig
	$(MAKE) -C $(KERNELDIR) O=$(BUILDDIR)/linux CONFIG_INITRAMFS_SOURCE=$(INITRAMFS) bzImage
	rm $(KERNELDIR)/arch/x86/configs/posix_defconfig

$(INITRAMFS): $(INIT) $(BUSYBOX)
	mkdir -p $(DESTDIR)
	install -d \
		$(DESTDIR)/usr/bin \
		$(DESTDIR)/etc \
		$(DESTDIR)/bin \
		$(DESTDIR)/sbin \
		$(DESTDIR)/sys \
		$(DESTDIR)/proc \
		$(DESTDIR)/dev \
		$(DESTDIR)/tmp
	install -m 0755 $(BUSYBOX) $(DESTDIR)/bin/busybox
	install -m 0755 $(INIT) $(DESTDIR)/init
	mknod -m 0620 $(DESTDIR)/dev/console c 5 1
	mknod -m 0666 $(DESTDIR)/dev/null c 1 3
	(cd $(DESTDIR) && find . -print0 | cpio --null -ov --format=newc > $(INITRAMFS))

$(BUSYBOX): $(BB_DEFCONFIG)
	mkdir -p $(BUILDDIR)/busybox
	cp $(BB_DEFCONFIG) $(BUILDDIR)/busybox/.config
	$(MAKE) -C $(BBDIR) O=$(BUILDDIR)/busybox busybox

.PHONY: kernel
kernel: $(KERNEL)

.PHONY: busybox
busybox: $(BUSYBOX)

.PHONY: clean_kernel
clean_kernel:
	$(MAKE) -C $(KERNELDIR) mrproper

.PHONY: clean_busybox
clean_busybox:
	$(MAKE) -C $(BBDIR) mrproper

.PHONY: clean
clean:
	rm -rf $(BUILDDIR)

.PHONY: cleanall
cleanall: clean_kernel clean_busybox clean

.PHONY: run
run: $(KERNEL)
	qemu-system-x86_64 -kernel $(KERNEL) -append "console=ttyS0" -nographic
