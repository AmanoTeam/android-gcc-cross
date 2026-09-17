# Builds the stub shared libraries (libc.so, libm.so, libdl.so) for the
# android-gcc-cross sysroots with the toolchain's own per-API GCC drivers.
#
# The stubs are generated the same way AOSP generates them for the NDK: the
# vendored ndkstubgen (soong/cc/ndkstubgen + soong/cc/symbolfile) reads each
# library's symbol file (bionic's libc.map.txt / libm.map.txt / libdl.map.txt),
# filters it for the target arch and API level, and emits a stub C file (one
# empty function per exported symbol, one variable per exported object), a
# version script, and an abigail symbol list. The stub C is compiled with
# -nostdlib: the stub carries no code, no DT_NEEDED, and no crt artifacts; it
# only gives the linker the symbols, the SONAME, and the version tags
# (foo@@LIBC). At runtime the device's real bionic provides the implementation.
#
# Called by sysroot.sh after it has staged the sysroot directories: for every
# $(OUT)/<target><api>/lib directory present, the NDK-copied stub .so files
# are overwritten with GCC-built ones.
#
# Variables (command line or environment):
#   OUT         sysroot staging root (default: /tmp/bionic-libraries)
#   BIONIC_DIR  bionic checkout (default: /tmp/bionic, where sysroot.sh clones it)
#   GEN         scratch dir for generated sources (default: /tmp/ndk-stubs-gen)
#   ABIS        target triples (default: all four)
#   APIS        API levels (default: per-ABI, from the $(OUT) directories)
#   LIBS        stub libraries to build (default: the full NDK set except
#               libc++/libstdc++, which sysroot.sh removes; every NDK-exposed
#               library has its map file vendored under maps/)
#
# The per-API drivers (<target><api>-gcc) must be on PATH.

OUT       ?= /tmp/bionic-libraries
BIONIC_DIR ?= /tmp/bionic
GEN       ?= /tmp/ndk-stubs-gen
PY        ?= python3

LIBS ?= libc libm libdl libEGL libGLESv1_CM libGLESv2 libGLESv3 libandroid \
        libz liblog libjnigraphics libmediandk libOpenSLES libOpenMAXAL \
        libcamera2ndk libvulkan libaaudio libnativewindow libsync libamidi \
        libbinder_ndk libneuralnetworks libicu libnativehelper

ABIS ?= aarch64-unknown-linux-android armv7-unknown-linux-androideabi \
        i686-unknown-linux-android x86_64-unknown-linux-android

# Symbol files: the bionic ones from the checkout; the rest downloaded under
# maps/ by sysroot.sh from their upstream repos (noted per entry for
# maintenance).
map_libc         := $(BIONIC_DIR)/libc/libc.map.txt
map_libm         := $(BIONIC_DIR)/libm/libm.map.txt
map_libdl        := $(BIONIC_DIR)/libdl/libdl.map.txt
map_libEGL       := $(CURDIR)/maps/libEGL.map.txt         # frameworks/native opengl/libs
map_libGLESv1_CM := $(CURDIR)/maps/libGLESv1_CM.map.txt   # frameworks/native opengl/libs
map_libGLESv2    := $(CURDIR)/maps/libGLESv2.map.txt      # frameworks/native opengl/libs
map_libGLESv3    := $(CURDIR)/maps/libGLESv3.map.txt      # frameworks/native opengl/libs
map_libandroid   := $(CURDIR)/maps/libandroid.map.txt     # frameworks/base native/android
map_libz         := $(CURDIR)/maps/libz.map.txt           # external/zlib
map_liblog       := $(CURDIR)/maps/liblog.map.txt         # system/logging liblog
map_libjnigraphics := $(CURDIR)/maps/libjnigraphics.map.txt # frameworks/base native/graphics/jni
map_libmediandk  := $(CURDIR)/maps/libmediandk.map.txt    # frameworks/av media/ndk
map_libOpenSLES  := $(CURDIR)/maps/libOpenSLES.map.txt    # frameworks/wilhelm src
map_libOpenMAXAL := $(CURDIR)/maps/libOpenMAXAL.map.txt   # frameworks/wilhelm src
map_libcamera2ndk := $(CURDIR)/maps/libcamera2ndk.map.txt # frameworks/av camera/ndk
map_libvulkan    := $(CURDIR)/maps/libvulkan.map.txt      # frameworks/native vulkan/libvulkan
map_libaaudio    := $(CURDIR)/maps/libaaudio.map.txt       # frameworks/av media/libaaudio/src
map_libnativewindow := $(CURDIR)/maps/libnativewindow.map.txt # frameworks/native libs/nativewindow
map_libsync      := $(CURDIR)/maps/libsync.map.txt        # system/core libsync
map_libamidi     := $(CURDIR)/maps/libamidi.map.txt       # frameworks/base media/native/midi
map_libbinder_ndk := $(CURDIR)/maps/libbinder_ndk.map.txt # frameworks/native libs/binder/ndk
map_libneuralnetworks := $(CURDIR)/maps/libneuralnetworks.map.txt # packages/modules/NeuralNetworks runtime
map_libicu       := $(CURDIR)/maps/libicu.map.txt         # external/icu libicu
map_libnativehelper := $(CURDIR)/maps/libnativehelper.map.txt # libnativehelper (repo root)

# ndk_library first_version (AOSP): below this API level the library does not
# exist, so no stub is built for it.
first_version_libc         = 9
first_version_libm         = 9
first_version_libdl        = 9
first_version_libEGL       = 9
first_version_libGLESv1_CM = 9
first_version_libGLESv2    = 9
first_version_libGLESv3    = 18
first_version_libandroid   = 9
first_version_libz         = 9
first_version_liblog       = 9
first_version_libjnigraphics = 9
first_version_libmediandk  = 21
first_version_libOpenSLES  = 9
first_version_libOpenMAXAL = 14
first_version_libcamera2ndk = 24
first_version_libvulkan    = 24
first_version_libaaudio    = 26
first_version_libnativewindow = 26
first_version_libsync      = 26
first_version_libamidi     = 29
first_version_libbinder_ndk = 29
first_version_libneuralnetworks = 27
first_version_libicu       = 31
first_version_libnativehelper = 31

arch_aarch64-unknown-linux-android  = arm64
arch_armv7-unknown-linux-androideabi = arm
arch_i686-unknown-linux-android      = x86
arch_x86_64-unknown-linux-android    = x86_64

STUBGEN     := $(CURDIR)/ndkstubgen.py
SYMBOLFILE  := $(CURDIR)/symbolfile.py
API_MAP     := $(CURDIR)/api-map.json

# API levels: from the sysroot directories sysroot.sh staged, or APIS.
sysroot_apis = $(shell ls -d $(OUT)/$(1)*[0-9] 2>/dev/null | sed 's|.*$(1)||' | sort -n)
apis_of = $(if $(APIS),$(APIS),$(call sysroot_apis,$(1)))

# Same compiler flags Soong applies to stub libraries (cc/ndk_library.go):
# the generated sources define builtins and setjmp without their headers. GCC
# additionally needs -fno-builtin (empty redefinitions of builtins are the
# point of a stub) and -Wno-builtin-declaration-mismatch, which names the
# diagnostic clang calls -Wno-builtin-requires-header's cousin.
STUB_CFLAGS := -O2 -fPIC -fno-builtin -Wall -Werror -fno-unwind-tables \
  -Wno-incompatible-library-redeclaration \
  -Wno-incomplete-setjmp-declaration \
  -Wno-builtin-requires-header \
  -Wno-builtin-declaration-mismatch \
  -Wno-invalid-noreturn

# (1)=target (2)=api (3)=lib: generate the stub sources, then the stub itself.
# ndkstubgen writes the version script and symbol list as side effects of the
# stub source, so only the .c is a make target; the .so rule reads the script
# at its deterministic path.
define STUB_GEN_RULE
$$(GEN)/$(1)$(2)/$(3).c: $(map_$(3)) $$(STUBGEN) $$(SYMBOLFILE)
	@mkdir -p $$(dir $$@)
	$$(PY) $$(STUBGEN) --api $(2) --arch $(arch_$(1)) --api-map $$(API_MAP) \
	  $(map_$(3)) $$@ $$(GEN)/$(1)$(2)/$(3).script $$(GEN)/$(1)$(2)/$(3).list
endef

define STUB_SO_RULE
$$(OUT)/$(1)$(2)/lib/$(3).so: $$(GEN)/$(1)$(2)/$(3).c
	@mkdir -p $$(dir $$@)
	$(1)$(2)-gcc -shared -nostdlib -Wl,-soname,$(3).so \
	  -Wl,--version-script=$$(GEN)/$(1)$(2)/$(3).script $$(STUB_CFLAGS) -o $$@ $$<
endef

STUB_OBJS :=
$(foreach target,$(ABIS),\
  $(foreach api,$(call apis_of,$(target)),\
    $(foreach lib,$(LIBS),\
      $(if $(shell test $(api) -ge $(first_version_$(lib)) && echo y),\
        $(eval STUB_OBJS += $(OUT)/$(target)$(api)/lib/$(lib).so) \
        $(eval $(call STUB_GEN_RULE,$(target),$(api),$(lib))) \
        $(eval $(call STUB_SO_RULE,$(target),$(api),$(lib)))))))

.DEFAULT_GOAL := all
.PHONY: all clean

all: $(STUB_OBJS)

clean:
	rm -rf $(GEN)
	rm -f $(STUB_OBJS)
