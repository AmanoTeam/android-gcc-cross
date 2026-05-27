# android-gcc-cross

This version of GCC uses the patchset from the [TUR](https://github.com/termux-user-repository/tur/tree/master/tur/gcc-15) port of GCC for Android, with additional patches to improve cross-compilation support and enable its usage in Gradle projects as a replacement for Clang.

## Installation

### Termux

<details>
Although the toolchain is mainly intended for cross-compilation, you can also install it on Termux and use it as a native compiler:

```bash
curl \
    --silent \
    --show-error \
    --fail \
    --url 'https://cdn.jsdelivr.net/gh/AmanoTeam/android-gcc-cross@master/tools/termux-install.sh' \
        | bash
```

This will download the GCC toolchain and install it to `/data/data/com.termux/files/usr/lib/android-gcc-cross`. After that, you can use the usual `gcc` and `g++` to compile code directly from Termux.
</details>

### Other platforms

* [Windows](https://github.com/AmanoTeam/android-gcc-cross/releases/latest/download/x86_64-w64-mingw32.zip)
* [macOS](https://github.com/AmanoTeam/android-gcc-cross/releases/latest/download/aarch64-apple-darwin.tar.xz)
* [Linux](https://github.com/AmanoTeam/android-gcc-cross/releases/latest/download/x86_64-unknown-linux-gnu.tar.xz)

## Usage

### Gradle projects

Replacing Clang is a bit tricky. Both CMake and ndk-build are heavily tied to the NDK’s internal structure, which makes it difficult to completely replace the compiler toolchain without risking breaking something in the build process.

For this to work, you will need to have both our GCC toolchain and the upstream Clang toolchain installed.

First, ensure that the NDK is already installed. If you are using ndk-build or CMake with Gradle and have built your project at least once on your machine, it is very likely that the NDK is already installed. If you're unsure, go to the root directory of your project and run `./gradlew clean`:

```
$ ./gradlew clean
Starting a Gradle Daemon (subsequent builds will be faster)

> Configure project :
Checking the license for package NDK (Side by side) 25.1.8937393 in /home/runner/sdk/licenses
License for package NDK (Side by side) 25.1.8937393 accepted.
Preparing "Install NDK (Side by side) 25.1.8937393 v.25.1.8937393".
"Install NDK (Side by side) 25.1.8937393 v.25.1.8937393" ready.
Installing NDK (Side by side) 25.1.8937393 in /home/runner/sdk/ndk/25.1.8937393
"Install NDK (Side by side) 25.1.8937393 v.25.1.8937393" complete.
"Install NDK (Side by side) 25.1.8937393 v.25.1.8937393" finished.

> Task :externalNativeBuildCleanDebug
> Task :externalNativeBuildCleanRelease
> Task :clean UP-TO-DATE

BUILD SUCCESSFUL in 44s
3 actionable tasks: 2 executed, 1 up-to-date
```

If you see messages like `Install NDK [...]` after running the above command, then Gradle just installed the NDK for you. If you don't see any messages like this, then either the NDK is already installed or the project you are trying to compile is not using the NDK at all.

#### Patching the NDK

The toolchain ships with a utility named `ndk-patch` that can be used to patch the NDK so that Gradle picks up GCC instead of Clang for cross-compilation. Running it will output something like this:

```
$ <android-gcc-cross>/bin/ndk-patch
- Symlinking /home/runner/android-gcc-cross/bin/clang to /usr/local/lib/android/sdk/ndk/25.1.8937393/toolchains/llvm/prebuilt/linux-x86_64/bin/clang
- Symlinking /home/runner/android-gcc-cross/bin/clang++ to /usr/local/lib/android/sdk/ndk/25.1.8937393/toolchains/llvm/prebuilt/linux-x86_64/bin/clang++
...
```

Essentially, it overrides the locally installed NDK’s `clang`/`clang++` commands with alternatives that invoke `gcc`/`g++` instead.

#### Building the project

After patching the NDK, you are almost ready to go and compile the project. Just run `./gradlew clean` before compiling it to make sure compiled objects from previous builds (Clang) don't interfere with the new build.

### CMake

The upstream NDK provides a single, unified CMake toolchain for cross-compilation, typically located at `<ndk-prefix>/build/cmake/android.toolchain.cmake`. In contrast, we provide a separate toolchain for each supported architecture/API level. These toolchains can be found in `<android-gcc-cross>/build/cmake`:

```bash
$ ls <android-gcc-cross>/build/cmake
aarch64-unknown-linux-android.cmake
aarch64-unknown-linux-android21.cmake
aarch64-unknown-linux-android22.cmake
...
arm-unknown-linux-androideabi.cmake
arm-unknown-linux-androideabi21.cmake
arm-unknown-linux-androideabi22.cmake
...
i686-unknown-linux-android.cmake
i686-unknown-linux-android21.cmake
i686-unknown-linux-android22.cmake
...
riscv64-unknown-linux-android.cmake
riscv64-unknown-linux-android35.cmake
...
x86_64-unknown-linux-android.cmake
x86_64-unknown-linux-android21.cmake
x86_64-unknown-linux-android22.cmake
```

So, instead of configuring your project like this...

```
$ cmake \
    -DCMAKE_TOOLCHAIN_FILE='<ndk-prefix>/build/cmake/android.toolchain.cmake' \
    -DANDROID_ABI='armeabi-v7a' \
    -DANDROID_PLATFORM='android-24' \
    ...
```

...prefer this instead:

```
$ cmake \
    -DCMAKE_TOOLCHAIN_FILE='<android-gcc-cross>/build/cmake/arm-unknown-linux-androideabi24.cmake' \
    ...
```

### Autotools

For convenience, the toolchain also provides helper scripts that can be used to set up an environment suitable for cross-compiling projects based on Autotools and similar tools. These scripts can be found in `<android-gcc-cross>/build/autotools`:

```bash
$ ls <android-gcc-cross>/build/autotools
aarch64-unknown-linux-android.sh
aarch64-unknown-linux-android21.sh
aarch64-unknown-linux-android22.sh
...
arm-unknown-linux-androideabi.sh
arm-unknown-linux-androideabi21.sh
arm-unknown-linux-androideabi22.sh
...
i686-unknown-linux-android.sh
i686-unknown-linux-android21.sh
i686-unknown-linux-android22.sh
...
riscv64-unknown-linux-android.sh
riscv64-unknown-linux-android35.sh
...
x86_64-unknown-linux-android.sh
x86_64-unknown-linux-android21.sh
x86_64-unknown-linux-android22.sh
```

They are meant to be `source`d by you whenever you want to cross-compile a project:

```bash
# Set up the environment for cross-compilation
$ source <android-gcc-cross>/build/autotools/aarch64-unknown-linux-android21.sh

# Configure & build the project
$ ./configure --host="${CROSS_COMPILE_TRIPLET}"
$ make
```

Essentially, these scripts handle the setup of `CC`, `CXX`, `LD`, and other environment variables so you don’t need to configure them manually.

## Changing some behaviors

The toolchain allows you to change its behavior in certain scenarios through the use of environment variables. Below are all the switches it supports and their intended purposes:

- `PINO_RUNTIME_RPATH`  
  - Automatically appends the path to the directory containing GCC libraries (e.g., libsanitizer (AddressSanitizer), libatomic, and libstdc++) to your executables’ RPATH. This is only useful when running inside Termux.

- `PINO_STATIC_RUNTIME`  
  - Tells the cross-compiler to prefer linking with the static versions of the GCC runtime libraries rather than the dynamic ones. See [Static vs dynamic linking](#static-vs-dynamic-linking).

- `PINO_NEON`  
  - Tells the cross-compiler to enable support for NEON intrinsics on ARMv7. See [NEON intrinsics](#neon-intrinsics).

- `PINO_ARM_MODE`  
  - Tells the cross-compiler to generate code in ARM mode rather than Thumb-1/Thumb-2 mode.

- `PINO_LTO`  
  - Tells the cross-compiler to use LTO (Link-Time Optimization) during the build process. This flag accepts a string instead of a boolean, and the values for it can be `thin` or `full`.

Most options, unless specified otherwise, take a boolean. You can enable a switch by setting its value to `true` (e.g., `export PINO_NZ=true`), and disable it by setting its value to `false` (e.g., `export PINO_NZ=false`).

## Software availability

The cross-compiler ships only with the minimum required to build a working C/C++ program. That is, you won't find any prebuilt binaries of popular projects like OpenSSL or zlib available for use, as you would on an average Linux distribution.

If your project depends on something other than the Bionic C library (or the C++ standard libraries, for C++ programs), you need to either build it yourself or install it from somewhere else. For convenience, the toolchain includes an APT-like utility that installs packages from remote repositories into a local directory and makes them available for use during cross-compilation.

Below is an example of building a CMake project that uses prebuilt dependencies installed through the package manager:

1. Fetch the project sources (using curl as an example):

    ```bash
    git clone https://github.com/curl/curl
    cd curl
    ```

2. Configure the environment for cross-compilation:

    ```bash
    source <android-gcc-cross>/build/autotools/aarch64-unknown-linux-android24.sh
    ```

3. Install the required dependencies:

    ```bash
    <android-gcc-cross>/bin/aarch64-unknown-linux-android24-apt install libnghttp2-static openssl-static zlib-static libpsl-static
    ```

4. Build curl as usual:

    ```bash
    cmake -S . -B build
    cmake --build build
    ```

## ABIs

The NDK has its own page explaining its supported architectures and ABIs (see [Android ABIs](https://developer.android.com/ndk/guides/abis)), but since our toolchain differs from the upstream NDK in some aspects, this section covers the specifics of both and compares their behavior.

<!--
> [!NOTE]  
> The ABIs `armeabi`, `mips`, and `mips64` are obsolete in the upstream NDK and are no longer available for cross-compilation in modern versions of the toolchain. Pino, however, has restored support for those architectures.
-->

### `armeabi-v7a`

This refers to the ARMv7-A system architecture. Just like the Clang NDK, our toolchain uses `softfp` hardware floating-point and generates code in `Thumb-2` mode by default.

The Clang NDK defaults to using the `VFPv3-D32` floating-point unit along with the **ARM Advanced SIMD (Neon)** extension. Our toolchain, however, defaults to using the `VFPv3-D16` floating-point unit and disables the Neon extension by default.

The reason for using `VFPv3-D16` instead of `VFPv3-D32` and disabling Neon is to support backward compatibility with older hardware. When first introduced in the NDK, the ARMv7-A target didn't require `VFPv3-D32` and `Neon`; they were completely optional features, so there might still be hardware around that doesn't support these instruction sets. Also, not everyone needs those fancy floating-point operations. If for some reason you do, enable it manually.

### `arm64-v8a`

This refers to the ARMv8 system architecture. Our toolchain enables PAC (Pointer Authentication Code) and BTI (Branch Target Identification) by default for this architecture, while on Clang, these features are optional. Other than that, there are no differences between our toolchain and the upstream NDK.

### `x86`

This refers to the i386 system architecture. Just like the upstream NDK, GCC also assumes a 16-byte stack alignment before a function call. There are no additional differences between the ABI supported by our toolchain and the ABI supported by the upstream NDK.

### `x86_64`

This refers to the x64 system architecture. There are no additional differences between the ABI supported by our toolchain and the ABI supported by the upstream NDK.

### `riscv64`

This refers to the RISC-V system architecture. There is currently no ABI page for this architecture in the Android documentation, so I can't make a proper comparison. Our toolchain emits code for the RV64GC architecture on the LP64D (hardfloat double) ABI by default.

<!--
### `armeabi`

This refers to the ARMv5TE system architecture. It uses `softfp` hardware floating-point and generates code in `Thumb-1` mode. The `VFPv2` floating-point unit is the default, without the Neon extension. This matches the upstream NDK.

### `mips`

This refers to the MIPS32r2 system architecture. It uses `hard` hardware floating-point and generates code targeting the 32-bit ABI by default, optionally supporting the o32 ABI as well. This matches the upstream NDK.

### `mips64`

This refers to the MIPS64r6 system architecture. It uses `hard` hardware floating-point and generates code targeting the 64-bit ABI by default. This matches the upstream NDK.
-->

### Static vs dynamic linking

The toolchain provides a flag switch with functionality similar to the NDK's [ANDROID_STL/APP_STL](https://developer.android.com/ndk/guides/cpp-support#selecting_a_c_runtime) flag. It allows you to choose between static and shared runtimes when linking C/C++ code:

```nim
PINO_STATIC_RUNTIME: bool = [true/false]
```

* Setting `PINO_STATIC_RUNTIME = true` is equivalent to setting `ANDROID_STL = c++_static` in the upstream NDK.
* Setting `PINO_STATIC_RUNTIME = false` is equivalent to setting `ANDROID_STL = c++_shared` in the upstream NDK.

By default, `PINO_STATIC_RUNTIME` assumes no specific behavior and will use whatever value was passed to `ANDROID_STL` in CMake/ndk-build.

### NEON Intrinsics

Unlike the upstream NDK, our toolchain disables NEON by default for the `armeabi-v7a` target. The reasoning behind this is explained [here](#armeabi-v7a).

If you want to enable NEON intrinsics, you can set the `PINO_NEON` environment variable:

```nim
PINO_NEON: bool = [true/false]
```

## Known bugs/limitations

- `-D_FORTIFY_SOURCE` has no effect.
  - The fortify headers shipped with the NDK currently rely on Clang-specific syntax that is not supported by GCC. We need to either adapt these headers or migrate to a GCC-compatible alternative, such as [fortify-headers](https://github.com/jvoisin/fortify-headers).
- The HWAddressSanitizer (`-fsanitize=hwaddress`) runtime is broken.
  - It requires ELF TLS support and possibly other missing components (not fully investigated). If you really need it, use the older AddressSanitizer implementation (`-fsanitize=address`) implementation instead.

## Releases

* [GCC 15](https://github.com/AmanoTeam/android-gcc-cross/releases/tag/gcc-15) - current stable release
* [GCC 16](https://github.com/AmanoTeam/android-gcc-cross/releases/tag/gcc-16) - current stable release

The current stable release is based on GCC 15/16 and supports cross-compiling software for all major Android architectures: `armv7`, `arm64`, `x86`, and `x86_64`. There is also experimental support for the `riscv64` architecture.

<!--
Additionally, it supports cross-compiling software for architectures whose support has been deprecated in the upstream NDK, including `armv5`, `mips`, and `mips64`.
-->

The toolchain includes support for the C and C++ frontends.

The toolchain supports targeting Android versions from 4.0.1 (API level 14) up to Android 16 (API level 36).

## License

For detailed information, please refer to the [LICENSE](https://github.com/AmanoTeam/android-gcc-cross/blob/master/LICENSE.md) file.

## Disclaimer

Android is a registered trademark of Google LLC. This project is an independent open-source effort and is not affiliated with or endorsed by Google LLC.
