# Builds the CRT objects for the android-gcc-cross sysroots with the toolchain's
# own per-API GCC drivers, from the bionic sources:
#   crtbegin_dynamic.o  crtbegin_static.o  crtbegin_so.o
#   crtend_android.o    crtend_so.o        crt_pad_segment.o
#
# Same object set as the NDK's ndk/crtobjectbuilder.py (platform/ndk), minus the
# .note.android.ident brand merge: the note is not required on Android, so each
# object is a plain gcc -c of the matching bionic source.
#
# Called by sysroot.sh after it has staged the sysroot directories: for every
# $(OUT)/<target><api>/lib directory present, all six objects are built into it.
# Set APIS to build an explicit API set instead (creating directories as
# needed).
#
# Variables (command line or environment):
#   OUT         sysroot staging root (default: /tmp/bionic-libraries)
#   BIONIC_DIR  bionic checkout (default: /tmp/bionic, where sysroot.sh clones it)
#   ABIS        target triples (default: all four)
#   APIS        API levels (default: per-ABI, from the $(OUT) directories)
#
# The per-API drivers (<target><api>-gcc) must be on PATH.

OUT       ?= /tmp/bionic-libraries
BIONIC_DIR ?= /tmp/bionic
CRT_SRC   := $(BIONIC_DIR)/libc/arch-common/bionic

ABIS ?= aarch64-unknown-linux-android armv7-unknown-linux-androideabi \
        i686-unknown-linux-android x86_64-unknown-linux-android

archflags_aarch64-unknown-linux-android = -mbranch-protection=standard

# API levels: from the sysroot directories sysroot.sh staged, or APIS.
sysroot_apis = $(shell ls -d $(OUT)/$(1)*[0-9] 2>/dev/null | sed 's|.*$(1)||' | sort -n)
apis_of = $(if $(APIS),$(APIS),$(call sysroot_apis,$(1)))

CRT_NAMES := crtbegin_dynamic crtbegin_so crtbegin_static \
             crtend_android crtend_so crt_pad_segment

src_crtbegin_dynamic = crtbegin.c
src_crtbegin_so      = crtbegin_so.c
src_crtbegin_static  = crtbegin.c
src_crtend_android   = crtend.S
src_crtend_so        = crtend_so.S
src_crt_pad_segment   = crt_pad_segment.S

defines_crtbegin_static = -DCRTBEGIN_STATIC -D_FORCE_CRT_ATFORK
# bionic's asm paths (bionic_asm.h -> <features.h> -> <sys/cdefs.h> ->
# <android/api-level.h>) pull in C declarations; __ASSEMBLY__ (defined by Soong,
# global.go) keeps api-level.h's C content out of the assembler.
defines_crtend_android  = -D__ASSEMBLY__
defines_crtend_so       = -D__ASSEMBLY__
defines_crt_pad_segment = -D__ASSEMBLY__

# -Wno-prio-ctor-dtor: GCC 16 warns on crtbegin_so.c's reserved priorities.
CRT_CFLAGS := -I$(BIONIC_DIR)/libc -I$(CRT_SRC) \
  -O2 -fpic -c -Wa,--noexecstack -Wno-prio-ctor-dtor

# one gcc -c per object. (1)=target (2)=api (3)=crt name.
define CRT_RULE
$$(OUT)/$(1)$(2)/lib/$(3).o: $$(CRT_SRC)/$(src_$(3))
	@mkdir -p $$(dir $$@)
	$(1)$(2)-gcc $$(CRT_CFLAGS) $(archflags_$(1)) $(defines_$(3)) -o $$@ $$<
endef

CRT_OBJS :=
$(foreach target,$(ABIS),\
  $(foreach api,$(call apis_of,$(target)),\
    $(foreach name,$(CRT_NAMES),\
      $(eval CRT_OBJS += $(OUT)/$(target)$(api)/lib/$(name).o) \
      $(eval $(call CRT_RULE,$(target),$(api),$(name))))))

.DEFAULT_GOAL := all
.PHONY: all clean

all: $(CRT_OBJS)

clean:
	rm -f $(CRT_OBJS)
