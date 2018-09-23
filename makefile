CONFIGURE := configure
AUTORECONF := autoreconf

VULKAN_CFLAGS = -I$(abspath ../vulkan-headers/include)
SPIRV_CFLAGS = -I$(abspath ../spirv-headers/include)

CCFLAGS ?= -O2 -march=native -fomit-frame-pointer -g0 -fipa-pta $(VULKAN_CFLAGS) $(SPIRV_CFLAGS)

CONFIGURE_FLAGS += \
	--prefix=/ \
	--disable-static \
	--disable-ld-version-script \
	--disable-maintainer-mode \
	--with-xcb \
	--with-spirv-tools

ifndef VERBOSE
CONFIGURE += --quiet
AUTORECONF += >$(abspath autoreconfoutput.log)
SILENCE_IS_GOLDEN = &>output-$$$$.log || cat output-$$$$.log; rm output-$$$$.log
.SILENT:
endif

dist:: dist.tar.xz

rebuild::
	+$(MAKE) -C build/wine64 build/wine32

clean::
	rm -Rf build/

build/wine32/Makefile: configure makefile
	echo "Configuring 32-bit vkd3d libraries..."
	mkdir -p $(dir $@)
	cd $(dir $@) && ../../$(CONFIGURE) --host="i686-pc-linux-gnu" $(CONFIGURE_FLAGS) --libdir=/lib LDFLAGS="-m32" CFLAGS="-m32 $(CCFLAGS)" PKG_CONFIG_PATH=/usr/lib32/pkgconfig $(SILENCE_IS_GOLDEN)

build/wine64/Makefile: configure makefile
	echo "Configuring 64-bit vkd3d libraries..."
	mkdir -p $(dir $@)
	cd $(dir $@) && ../../$(CONFIGURE) --host="x86_64-pc-linux-gnu" $(CONFIGURE_FLAGS) --libdir=/lib64 LDFLAGS="-m64" CFLAGS="-m64 $(CCFLAGS)" $(SILENCE_IS_GOLDEN)

aclocal.m4:
	echo "Setting up vkd3d local configuration..."
	$(AUTORECONF) -if $(SILENCE_IS_GOLDEN)
	rm -Rf autom4te.cache

configure.ac: aclocal.m4

configure: configure.ac
	autoconf $(SILENCE_IS_GOLDEN)

makefiles: build/wine64/Makefile build/wine32/Makefile

build/%: build/%/Makefile
	echo "Building $(@:build/wine%=%)-bit vkd3d libraries..."
	+$(MAKE) -C $@ $(SILENCE_IS_GOLDEN)

dist/lib/libvkd3d.so: build/wine32
dist/lib64/libvkd3d.so: build/wine64

dist/lib/libvkd3d.so dist/lib64/libvkd3d.so:
	+$(MAKE) -C $< DESTDIR=$(abspath dist) install-strip $(SILENCE_IS_GOLDEN)

install: dist/lib/libvkd3d.so dist/lib64/libvkd3d.so

dist.tar.xz: dist/lib/libvkd3d.so dist/lib64/libvkd3d.so
	echo "Creating vkd3d distribution..."
	tar cJf $@ dist/
