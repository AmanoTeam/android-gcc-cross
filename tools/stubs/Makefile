# Compiler and tools
CC      := gcc
AR      := ar
CFLAGS  := -O2 -Dhidden=__LIBC_HIDDEN__ -Dcomplex=_Complex -fvisibility=hidden
ARFLAGS := rcs

# Directories
LIBC_DIR := libc
LIBM_DIR := libm
BUILD_DIR := build

LIBC_BUILD := $(BUILD_DIR)/libc
LIBM_BUILD := $(BUILD_DIR)/libm

# Source files
LIBC_SRCS := $(wildcard $(LIBC_DIR)/*.c)
LIBM_SRCS := $(wildcard $(LIBM_DIR)/*.c)

# Object files
LIBC_OBJS := $(patsubst $(LIBC_DIR)/%.c,$(LIBC_BUILD)/%.o,$(LIBC_SRCS))
LIBM_OBJS := $(patsubst $(LIBM_DIR)/%.c,$(LIBM_BUILD)/%.o,$(LIBM_SRCS))

# Output libraries
LIBC_A := libc_stb.a
LIBM_A := libm_stb.a

# Default target
all: $(LIBC_A) $(LIBM_A)

# Build libc.a
$(LIBC_A): $(LIBC_OBJS)
	$(AR) $(ARFLAGS) $@ $^

# Build libm.a
$(LIBM_A): $(LIBM_OBJS)
	$(AR) $(ARFLAGS) $@ $^

# Compile libc objects
$(LIBC_BUILD)/%.o: $(LIBC_DIR)/%.c
	@mkdir -p $(LIBC_BUILD)
	$(CC) $(CFLAGS) -c $< -o $@

# Compile libm objects
$(LIBM_BUILD)/%.o: $(LIBM_DIR)/%.c
	@mkdir -p $(LIBM_BUILD)
	$(CC) $(CFLAGS) -c $< -o $@

# Clean
clean:
	rm -rf $(BUILD_DIR) $(LIBC_A) $(LIBM_A)

.PHONY: all clean
