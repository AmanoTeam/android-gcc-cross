OUT       ?= /tmp/bionic-libraries
BIONIC_DIR ?= /tmp/bionic
CRT_SRC   := $(BIONIC_DIR)/libc/arch-common/bionic

ABIS ?= aarch64-unknown-linux-android armv7-unknown-linux-androideabi \
        i686-unknown-linux-android x86_64-unknown-linux-android

archflags_aarch64-unknown-linux-android = -mbranch-protection=standard

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
defines_crtend_android  = -D__ASSEMBLY__
defines_crtend_so       = -D__ASSEMBLY__
defines_crt_pad_segment = -D__ASSEMBLY__

CRT_CFLAGS := -I$(BIONIC_DIR)/libc -I$(CRT_SRC) \
  -O2 -fPIC -fno-stack-protector -c -Wa,--noexecstack -Wno-prio-ctor-dtor

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
