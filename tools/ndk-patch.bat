@echo off
setlocal EnableDelayedExpansion

:: 1. Check for Administrator privileges (Required for mklink on Windows)
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo fatal error: Administrator privileges are required to create symlinks using mklink. 1>&2
    echo Please right-click and run this script as Administrator. 1>&2
    exit /b 1
)

:: 2. Get the directory of the batch script (without trailing slash)
set "app_directory=%~dp0"
if "!app_directory:~-1!"=="\" set "app_directory=!app_directory:~0,-1!"

:: 3. Define arrays
set "binutils=addr2line ar as c++filt cpp elfedit dwp gcc-ar gcc-nm gcc-ranlib gcov gcov-dump gcov-tool gprof ld ld.bfd ld.gold lto-dump nm objcopy objdump ranlib readelf size strings strip"
set "versions=14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36"
set "triplets=aarch64-linux-android i686-linux-android arm-linux-androideabi x86_64-linux-android mips64el-linux-android mipsel-linux-android riscv64-linux-android"

:: Windows NDK uses the windows-x86_64 slug
set "slug=windows-x86_64"
set "symlinks=0"

:: Set extension for Windows binaries
set "EXT=.exe"

:: 4. Resolve Android SDK root
set "sdk_root="
set "fallback_sdk=%LOCALAPPDATA%\Android\Sdk"
if defined ANDROID_HOME set "sdk_root=!ANDROID_HOME!"
if not defined sdk_root if defined ANDROID_SDK_ROOT set "sdk_root=!ANDROID_SDK_ROOT!"
if not defined sdk_root if defined ANDROI set "sdk_root=!ANDROID_SDK_ROOT!"
if not defined sdk_root if exist "!fallback_sdk!\" set "sdk_root=!fallback_sdk!"

:: 5. Resolve Android NDK root
set "ndk_root="
if defined ANDROID_NDK_HOME set "ndk_root=!ANDROID_NDK_HOME!"
if not defined ndk_root if defined ANDROID_NDK_ROOT set "ndk_root=!ANDROID_NDK_ROOT!"
if not defined ndk_root if defined NDK_HOME set "ndk_root=!NDK_HOME!"
if not defined ndk_root if defined ANDROID_NDK set "ndk_root=!ANDROID_NDK!"
if not defined ndk_root if defined NDK set "ndk_root=!NDK!"

:: 6. Determine directories to process (Fixed Batch Quirk)
set "directories="

if defined sdk_root if exist "!sdk_root!\" (
    echo checking !sdk_root!
    for /d %%D in ("!sdk_root!\ndk\*") do (
        set "directories=!directories! "%%~D""
    )
    goto :PathsResolved
)

if defined ndk_root if exist "!ndk_root!\" (
    echo checking !ndk_root!
    set "directories="!ndk_root!""
    goto :PathsResolved
)

echo fatal error: unable to find SDK location: please define ANDROID_HOME or ANDROID_SDK_ROOT 1>&2
echo fatal error: you can also explicitly set the NDK location with ANDROID_NDK_HOME or ANDROID_NDK_ROOT 1>&2
exit /b 1

:PathsResolved
if "!directories!"=="" (
    echo nothing to do^^! 1>&2
    exit /b 0
)

:: 7. Iterate over NDK directories
for %%D in (!directories!) do (
    set "dir=%%~D"
    set "dest_base=!dir!\toolchains\llvm\prebuilt\%slug%\bin"
    set "toolchains_dir=!dir!\toolchains"

    :: Standard Clang and LLVM tools
    call :Symlink "!app_directory!\clang!EXT!" "!dest_base!\clang!EXT!"
    call :Symlink "!app_directory!\clang++!EXT!" "!dest_base!\clang++!EXT!"
    call :Symlink "!app_directory!\yasm!EXT!" "!dest_base!\yasm!EXT!"
    call :Symlink "!app_directory!\llvm-strip!EXT!" "!dest_base!\llvm-strip!EXT!"
    call :Symlink "!app_directory!\llvm-objcopy!EXT!" "!dest_base!\llvm-objcopy!EXT!"
    
    :: Architecture-independent LLVM tools
    call :Symlink "!app_directory!\x86_64-unknown-linux-android-ar!EXT!" "!dest_base!\llvm-ar!EXT!"
    call :Symlink "!app_directory!\x86_64-unknown-linux-android-nm!EXT!" "!dest_base!\llvm-nm!EXT!"
    call :Symlink "!app_directory!\x86_64-unknown-linux-android-ranlib!EXT!" "!dest_base!\llvm-ranlib!EXT!"

    :: Ninja
    set "ninja_src=!app_directory!\ninja!EXT!"
    set "cmake_dir=!sdk_root!\cmake"
    if exist "!ninja_src!" if exist "!cmake_dir!\" (
        for /d %%C in ("!cmake_dir!\*") do (
            call :Symlink "!ninja_src!" "%%~C\bin\ninja!EXT!"
			:: Link all DLLs from app_directory
			for %%F in ("!app_directory!\*.dll") do (
				call :Symlink "%%~F" "%%~C\bin\%%~nxF"
			)
        )
    )

    for %%T in (%triplets%) do (
        set "triplet=%%T"
        set "original_triplet=%%T"

        if "!triplet!"=="arm-linux-androideabi" (
            set "triplet=armv7a-linux-androideabi"
        )

        set "canonical_triplet=!triplet:-linux=-unknown-linux!"
        set "canonical_triplet=!canonical_triplet:armv7a=armv7!"

        :: Binutils
        for %%B in (%binutils%) do (
            set "src=!app_directory!\!canonical_triplet!-%%B!EXT!"
            set "dst=!dest_base!\!triplet!-%%B!EXT!"

            if exist "!src!" (
                call :Symlink "!src!" "!dst!"

                :: 4.9 toolchain mapping for older NDK structures
                set "subdir="
                if "!original_triplet!"=="aarch64-linux-android" set "subdir=!toolchains_dir!\!original_triplet!-4.9"
                if "!original_triplet!"=="arm-linux-androideabi" set "subdir=!toolchains_dir!\!original_triplet!-4.9"
                if "!original_triplet!"=="x86_64-linux-android" set "subdir=!toolchains_dir!\x86_64-4.9"
                if "!original_triplet!"=="i686-linux-android" set "subdir=!toolchains_dir!\x86-4.9"

                if not "!subdir!"=="" if exist "!subdir!\" (
                    set "dst_sub=!subdir!\prebuilt\%slug%\bin\!original_triplet!-%%B!EXT!"
                    call :Symlink "!src!" "!dst_sub!"
                )

                if not "!original_triplet!"=="!triplet!" (
                    set "dst_orig=!dest_base!\!original_triplet!-%%B!EXT!"
                    call :Symlink "!src!" "!dst_orig!"
                )
            )
        )

        :: Versions
        for %%V in (%versions%) do (
            set "src=!app_directory!\!canonical_triplet!%%V-clang!EXT!"
            set "dst=!dest_base!\!triplet!%%V-clang!EXT!"
            
            if exist "!src!" (
                call :Symlink "!src!" "!dst!"
                
                set "src_pp=!app_directory!\!canonical_triplet!%%V-clang++!EXT!"
                set "dst_pp=!dest_base!\!triplet!%%V-clang++!EXT!"
                call :Symlink "!src_pp!" "!dst_pp!"
            )
        )
    )
)

:: 8. Summary
if !symlinks! equ 0 (
    echo nothing to do^^! 1>&2
) else (
    echo !symlinks! files were modified
)

exit /b 0

:: ===============================================================
:: Subroutine: Symlink
:: Safely force-creates a symlink mimicking bash `ln -sf`
:: ===============================================================
:Symlink
set "src_file=%~1"
set "dst_file=%~2"

:: Create the target folder just in case it's missing
for %%A in ("%dst_file%") do set "dst_dir=%%~dpA"
if not exist "%dst_dir%" mkdir "%dst_dir%" 2>nul

:: Force delete destination if it exists
if exist "%dst_file%" del /f /q "%dst_file%" 2>nul

echo symlinking %src_file% to %dst_file%
mklink "%dst_file%" "%src_file%" >nul 2>&1

set /a symlinks+=1
exit /b
