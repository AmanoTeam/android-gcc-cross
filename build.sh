#!/usr/bin/env bash

declare -r workdir="${PWD}"

git submodule update --init --depth='1'
git -C "${workdir}/submodules/nz" submodule update --init --depth='1'

declare -r build="$("${workdir}/submodules/obggcc/tools/config.guess")"

if [ -z "${CROSS_COMPILE_TRIPLET}" ]; then
	declare -r host="${build}"
	declare -r native='1'
else
	declare -r host="${CROSS_COMPILE_TRIPLET}"
	declare -r native='0'
fi

if [ -z "${PINO_BUILD_DIRECTORY}" ]; then
	declare -r build_directory='/var/tmp/android-gcc-cross-build'
else
	declare -r build_directory="${PINO_BUILD_DIRECTORY}"
fi

if [ -z "${PINO_BUILD_PARALLEL_LEVEL}" ]; then
	declare -r max_jobs="$(nproc)"
else
	declare -r max_jobs="${PINO_BUILD_PARALLEL_LEVEL}"
fi

if [ -z "${PINO_RELEASE}" ]; then
	declare -r gcc_major='16'
else
	declare -r gcc_major="${PINO_RELEASE}"
fi

set -eu

mkdir -p "${build_directory}"

declare -r toolchain_directory="${build_directory}/android-gcc-cross"
declare -r share_directory="${toolchain_directory}/usr/local/share/android-gcc-cross"

declare -r environment="LD_LIBRARY_PATH=${toolchain_directory}/lib PATH=${PATH}:${toolchain_directory}/bin"

declare -r revision="$(git rev-parse --short HEAD)"

declare -r gmp_tarball="${build_directory}/gmp.tar.xz"
declare -r gmp_directory="${build_directory}/gmp"

declare -r mpfr_tarball="${build_directory}/mpfr.tar.gz"
declare -r mpfr_directory="${build_directory}/mpfr-master"

declare -r mpc_tarball="${build_directory}/mpc.tar.gz"
declare -r mpc_directory="${build_directory}/mpc-master"

declare -r isl_tarball="${build_directory}/isl.tar.gz"
declare -r isl_directory="${build_directory}/isl-master"

declare -r binutils_tarball="${build_directory}/binutils.tar.xz"
declare -r binutils_directory="${build_directory}/binutils"

declare -r gold_tarball="${build_directory}/gold.tar.xz"
declare -r gold_directory="${build_directory}/gold"

declare gcc_url='https://github.com/gcc-mirror/gcc/archive/master.tar.gz'
declare -r gcc_tarball="${build_directory}/gcc.tar.xz"
declare gcc_directory="${build_directory}/gcc-master"

declare -r libsanitizer_tarball="${build_directory}/libsanitizer.tar.xz"
declare -r libsanitizer_directory="${build_directory}/libsanitizer"

declare -r zlib_tarball="${build_directory}/zlib.tar.gz"
declare -r zlib_directory="${build_directory}/zlib-develop"

declare -r zstd_tarball="${build_directory}/zstd.tar.gz"
declare -r zstd_directory="${build_directory}/zstd-dev"

declare -r yasm_tarball="${build_directory}/yasm.tar.gz"
declare -r yasm_directory="${build_directory}/yasm-1.3.0"

declare -r ninja_tarball="${build_directory}/ninja.tar.gz"
declare -r ninja_directory="${build_directory}/ninja-master"

declare -r patchelf_tarball="${build_directory}/patchelf.tar.gz"
declare -r patchelf_directory="${build_directory}/patchelf-master"

declare -r elf_cleaner_tarball="${build_directory}/elf_cleaner.tar.gz"
declare -r elf_cleaner_directory="${build_directory}/termux-elf-cleaner-master"

declare -r gcc_tools_tarball="${build_directory}/gcc_tools.tar.xz"
declare -r gcc_tools_directory="${build_directory}/autotools"

declare -r nz_directory="${workdir}/submodules/nz"
declare -r nz_prefix="${build_directory}/nz"

declare -r pieflags='-fPIE'
declare -r ccflags='-w -O2'
declare -r linkflags='-Xlinker -s'

declare build_nz='1'

declare exe=''
declare dll='.so'

declare -ra targets=(
	# 'mipsel-unknown-linux-android'
	# 'mips64el-unknown-linux-android'
	# 'armv5-unknown-linux-androideabi'
	'armv7-unknown-linux-androideabi'
	'x86_64-unknown-linux-android'
	'aarch64-unknown-linux-android'
	'i686-unknown-linux-android'
	# 'riscv64-unknown-linux-android'
)

declare -ra ktargets=(
	'armv7-unknown-linux-androideabi'
)

declare -ra versions=(
	'14'
	'15'
	'16'
	'17'
	'18'
	'19'
	'20'
	'21'
	'22'
	'23'
	'24'
	'25'
	'26'
	'27'
	'28'
	'29'
	'30'
	'31'
	'32'
	'33'
	'34'
	'35'
	'36'
)

if [[ "${host}" = *'-mingw32' ]]; then
	build_nz='0'
	exe='.exe'
	dll='.dll'
fi

declare -r bionic_headers="${build_directory}/include"

declare -r gcc_wrapper="${build_directory}/gcc-wrapper${exe}"
declare -r binutils_llvm_wrapper="${build_directory}/binutils-llvm-wrapper${exe}"
declare -r binutils_gnu_wrapper="${build_directory}/binutils-gnu-wrapper${exe}"

declare -ra symlink_tools=(
	'addr2line'
	'ar'
	'as'
	'c++filt'
	'cpp'
	'elfedit'
	'dwp'
	'gcc-ar'
	'gcc-nm'
	'gcc-ranlib'
	'gcov'
	'gcov-dump'
	'gcov-tool'
	'gprof'
	'ld'
	'ld.bfd'
	'ld.gold'
	'lto-dump'
	'nm'
	'objcopy'
	'objdump'
	'ranlib'
	'readelf'
	'size'
	'strings'
	'strip'
)

declare -ra libraries=(
	'libstdc++'
	'libestdc++'
	'libatomic'
	'libssp'
	'libitm'
	'libsupc++'
	'libgcc'
	'libegcc'
	'libm2cor'
	'libm2iso'
	'libm2log'
	'libm2min'
	'libm2pim'
	'libobjc'
	'libgfortran'
	'libasan'
	'libhwasan'
	'liblsan'
	'libtsan'
	'libubsan'
	'libquadmath'
	'libcilkrts'
	'libvtv'
	'libgcov'
	'libmpx'
	'libmudflap'
	'libmudflapth'
	'libandroid-stb'
	'libc_stb'
	'libm_stb'
)

declare languages='c,c++'

declare -r PKG_CONFIG_PATH="${toolchain_directory}/lib/pkgconfig"
declare -r PKG_CONFIG_LIBDIR="${PKG_CONFIG_PATH}"
declare -r PKG_CONFIG_SYSROOT_DIR="${toolchain_directory}"

declare -r pkg_cv_ZSTD_CFLAGS="-I${toolchain_directory}/include"
declare -r pkg_cv_ZSTD_LIBS="-L${toolchain_directory}/lib -lzstd"
declare -r ZSTD_CFLAGS="-I${toolchain_directory}/include"
declare -r ZSTD_LIBS="-L${toolchain_directory}/lib -lzstd"

export \
	PKG_CONFIG_PATH \
	PKG_CONFIG_LIBDIR \
	PKG_CONFIG_SYSROOT_DIR \
	pkg_cv_ZSTD_CFLAGS \
	pkg_cv_ZSTD_LIBS \
	ZSTD_CFLAGS \
	ZSTD_LIBS

export \
	ac_cv_header_stdc='yes' \
	ac_cv_header_sys_statvfs_h='no'
	libat_cv_have_ifunc='no'

if [[ "${host}" = *'-android'* ]]; then
	export ac_cv_func_ffsll='yes'
fi

source "${workdir}/submodules/obggcc/utils.sh"

if ! [ -f "${gcc_tools_tarball}" ]; then
	curl \
		--url 'https://github.com/AmanoTeam/gcc-tools/releases/download/rolling/x86_64-unknown-linux-gnu.tar.xz' \
		--retry '30' \
		--retry-delay '0' \
		--retry-all-errors \
		--retry-max-time '0' \
		--show-error \
		--location \
		--silent \
		--output "${gcc_tools_tarball}"
	
	tar \
		--directory="$(dirname "${gcc_tools_directory}")" \
		--extract \
		--file="${gcc_tools_tarball}"
fi

if ! [ -f "${gmp_tarball}" ]; then
	curl \
		--url 'https://github.com/AmanoTeam/gmplib-snapshots/releases/latest/download/gmp.tar.xz' \
		--retry '30' \
		--retry-delay '0' \
		--retry-all-errors \
		--retry-max-time '0' \
		--show-error \
		--location \
		--silent \
		--output "${gmp_tarball}"
	
	tar \
		--directory="$(dirname "${gmp_directory}")" \
		--extract \
		--file="${gmp_tarball}"
	
	patch --directory="${gmp_directory}" --strip='1' --input="${workdir}/submodules/obggcc/patches/0001-Remove-hardcoded-RPATH-and-versioned-SONAME-from-libgmp.patch"
	
	sed \
		--in-place \
		's/-Xlinker --out-implib -Xlinker $lib/-Xlinker --out-implib -Xlinker $lib.a/g' \
		"${gmp_directory}/configure"
	
	echo -e 'all:\ninstall:' > "${gmp_directory}/tests/Makefile.in"
	echo -e 'all:\ninstall:' > "${gmp_directory}/demos/Makefile.in"
	echo -e 'all:\ninstall:' > "${gmp_directory}/doc/Makefile.in"
fi

if ! [ -f "${mpfr_tarball}" ]; then
	curl \
		--url 'https://github.com/AmanoTeam/mpfr/archive/master.tar.gz' \
		--retry '30' \
		--retry-all-errors \
		--retry-delay '0' \
		--retry-max-time '0' \
		--show-error \
		--location \
		--silent \
		--output "${mpfr_tarball}"
	
	tar \
		--directory="$(dirname "${mpfr_directory}")" \
		--extract \
		--file="${mpfr_tarball}"
	
	cd "${mpfr_directory}"
	autoreconf --force --install
	
	patch --directory="${mpfr_directory}" --strip='1' --input="${workdir}/submodules/obggcc/patches/0001-Remove-hardcoded-RPATH-and-versioned-SONAME-from-libmpfr.patch"
fi

if ! [ -f "${mpc_tarball}" ]; then
	curl \
		--url 'https://github.com/AmanoTeam/mpc/archive/master.tar.gz' \
		--retry '30' \
		--retry-all-errors \
		--retry-delay '0' \
		--retry-max-time '0' \
		--show-error \
		--location \
		--silent \
		--output "${mpc_tarball}"
	
	tar \
		--directory="$(dirname "${mpc_directory}")" \
		--extract \
		--file="${mpc_tarball}"
	
	cd "${mpc_directory}"
	autoreconf --force --install
	
	patch --directory="${mpc_directory}" --strip='1' --input="${workdir}/submodules/obggcc/patches/0001-Remove-hardcoded-RPATH-and-versioned-SONAME-from-libmpc.patch"
fi

if ! [ -f "${isl_tarball}" ]; then
	curl \
		--url 'https://github.com/AmanoTeam/isl/archive/master.tar.gz' \
		--retry '30' \
		--retry-all-errors \
		--retry-delay '0' \
		--retry-max-time '0' \
		--show-error \
		--location \
		--silent \
		--output "${isl_tarball}"
	
	tar \
		--directory="$(dirname "${isl_directory}")" \
		--extract \
		--file="${isl_tarball}"
	
	cd "${isl_directory}"
	autoreconf --force --install
	
	patch --directory="${isl_directory}" --strip='1' --input="${workdir}/submodules/obggcc/patches/0001-Remove-hardcoded-RPATH-and-versioned-SONAME-from-libisl.patch"
	
	for name in "${isl_directory}/isl_test"*; do
		echo 'int main() {}' > "${name}"
	done
	
	sed \
		--in-place \
		--regexp-extended \
		's/(allow_undefined)=.*$/\1=no/' \
		"${isl_directory}/ltmain.sh" \
		"${isl_directory}/interface/ltmain.sh"
fi

if ! [ -f "${binutils_tarball}" ]; then
	curl \
		--url 'https://github.com/AmanoTeam/binutils-snapshots/releases/latest/download/binutils.tar.xz' \
		--retry '30' \
		--retry-delay '0' \
		--retry-all-errors \
		--retry-max-time '0' \
		--location \
		--silent \
		--output "${binutils_tarball}"
	
	tar \
		--directory="$(dirname "${binutils_directory}")" \
		--extract \
		--file="${binutils_tarball}"
	
	if [[ "${host}" = *'-darwin'* ]]; then
		sed \
			--in-place \
			's/$$ORIGIN/@loader_path/g' \
			"${workdir}/submodules/obggcc/patches/0001-Add-relative-RPATHs-to-binutils-host-tools.patch"
	fi
	
	if [[ "${host}" = *'bsd'* ]] || [[ "${host}" = *'dragonfly' ]] then
		sed \
			--in-place \
			's/-Xlinker -rpath/-Xlinker -z -Xlinker origin -Xlinker -rpath/g' \
			"${workdir}/submodules/obggcc/patches/0001-Add-relative-RPATHs-to-binutils-host-tools.patch"
	fi
	
	patch --directory="${binutils_directory}" --strip='1' --input="${workdir}/submodules/obggcc/patches/0001-Add-relative-RPATHs-to-binutils-host-tools.patch"
	patch --directory="${binutils_directory}" --strip='1' --input="${workdir}/submodules/obggcc/patches/0001-Don-t-warn-about-local-symbols-within-the-globals.patch"
fi

if ! [ -f "${gold_tarball}" ]; then
	curl \
		--url 'https://github.com/AmanoTeam/binutils-snapshots/releases/latest/download/gold.tar.xz' \
		--retry '30' \
		--retry-all-errors \
		--retry-delay '0' \
		--retry-max-time '0' \
		--show-error \
		--location \
		--silent \
		--output "${gold_tarball}"
	
	tar \
		--directory="$(dirname "${gold_directory}")" \
		--extract \
		--file="${gold_tarball}"
	
	if [[ "${host}" = *'bsd'* ]] || [[ "${host}" = *'dragonfly' ]] then
		sed \
			--in-place \
			's/-Xlinker -rpath/-Xlinker -z -Xlinker origin -Xlinker -rpath/g' \
			"${workdir}/submodules/obggcc/patches/0001-Add-relative-RPATHs-to-gold-host-tools.patch"
	fi
	
	if [[ "${host}" = *'-darwin'* ]]; then
		sed \
			--in-place \
			's/$$ORIGIN/@loader_path/g' \
			"${workdir}/submodules/obggcc/patches/0001-Add-relative-RPATHs-to-gold-host-tools.patch"
	fi
	
	patch --directory="${gold_directory}" --strip='1' --input="${workdir}/submodules/obggcc/patches/0001-Revert-gold-Use-char16_t-char32_t-instead-of-uint16_t-uint32_t-as-character-types.patch"
	patch --directory="${gold_directory}" --strip='1' --input="${workdir}/submodules/obggcc/patches/0001-Make-gold-linker-ignore-unknown-z-options.patch"
	patch --directory="${gold_directory}" --strip='1' --input="${workdir}/submodules/obggcc/patches/0001-Add-relative-RPATHs-to-gold-host-tools.patch"
fi

if ! [ -f "${zlib_tarball}" ]; then
	curl \
		--url 'https://github.com/madler/zlib/archive/develop.tar.gz' \
		--retry '30' \
		--retry-all-errors \
		--retry-delay '0' \
		--retry-max-time '0' \
		--location \
		--silent \
		--output "${zlib_tarball}"
	
	tar \
		--directory="$(dirname "${zlib_directory}")" \
		--extract \
		--file="${zlib_tarball}"
	
	sed \
		--in-place \
		's/(UNIX)/(1)/g; s/(NOT APPLE)/(0)/g' \
		"${zlib_directory}/CMakeLists.txt"
fi

if ! [ -f "${zstd_tarball}" ]; then
	curl \
		--url 'https://github.com/facebook/zstd/archive/dev.tar.gz' \
		--retry '30' \
		--retry-delay '0' \
		--retry-all-errors \
		--retry-max-time '0' \
		--location \
		--silent \
		--output "${zstd_tarball}"
	
	tar \
		--directory="$(dirname "${zstd_directory}")" \
		--extract \
		--file="${zstd_tarball}"
	
	sed \
		--in-place \
		's/LANGUAGES C   # M/LANGUAGES C CXX  # M/g' \
		"${zstd_directory}/build/cmake/CMakeLists.txt"
fi

if ! [ -f "${yasm_tarball}" ]; then
	curl \
		--url 'https://deb.debian.org/debian/pool/main/y/yasm/yasm_1.3.0.orig.tar.gz' \
		--retry '30' \
		--retry-delay '0' \
		--retry-all-errors \
		--retry-max-time '0' \
		--location \
		--silent \
		--output "${yasm_tarball}"
	
	tar \
		--directory="$(dirname "${yasm_directory}")" \
		--extract \
		--file="${yasm_tarball}"
	
	cd "${yasm_directory}"
	autoreconf --force --install
fi

if ! [ -f "${ninja_tarball}" ]; then
	curl \
		--url 'https://github.com/ninja-build/ninja/archive/master.tar.gz' \
		--retry '30' \
		--retry-delay '0' \
		--retry-all-errors \
		--retry-max-time '0' \
		--location \
		--silent \
		--output "${ninja_tarball}"
	
	tar \
		--directory="$(dirname "${ninja_directory}")" \
		--extract \
		--file="${ninja_tarball}"
fi

if ! [ -f "${patchelf_tarball}" ]; then
	curl \
		--url 'https://github.com/NixOS/patchelf/archive/master.tar.gz' \
		--retry '30' \
		--retry-delay '0' \
		--retry-all-errors \
		--retry-max-time '0' \
		--location \
		--silent \
		--output "${patchelf_tarball}"
	
	tar \
		--directory="$(dirname "${patchelf_directory}")" \
		--extract \
		--file="${patchelf_tarball}"
fi

if ! [ -f "${elf_cleaner_tarball}" ]; then
	curl \
		--url 'https://github.com/termux/termux-elf-cleaner/archive/master.tar.gz' \
		--retry '30' \
		--retry-delay '0' \
		--retry-all-errors \
		--retry-max-time '0' \
		--location \
		--silent \
		--output "${elf_cleaner_tarball}"
	
	tar \
		--directory="$(dirname "${elf_cleaner_directory}")" \
		--extract \
		--file="${elf_cleaner_tarball}"
fi

export PATH="${build_directory}:${gcc_tools_directory}/bin:${PATH}"

if ! [ -f "${gcc_tarball}" ]; then
	if [ "${gcc_major}" != '17' ]; then
		gcc_url="https://github.com/gcc-mirror/gcc/archive/releases/gcc-${gcc_major}.tar.gz"
		gcc_directory="${build_directory}/gcc-releases-gcc-${gcc_major}"
	fi
	
	curl \
		--url "${gcc_url}" \
		--retry '30' \
		--retry-delay '0' \
		--retry-all-errors \
		--retry-max-time '0' \
		--location \
		--silent \
		--output "${gcc_tarball}"
	
	tar \
		--directory="$(dirname "${gcc_directory}")" \
		--extract \
		--file="${gcc_tarball}"
	
	if [[ "${host}" = *'-darwin'* ]]; then
		sed \
			--in-place \
			's/$$ORIGIN/@loader_path/g' \
			"${workdir}/submodules/obggcc/patches/0007-Add-relative-RPATHs-to-GCC-host-tools.patch"
	fi
	
	if [[ "${host}" = *'bsd'* ]] || [[ "${host}" = *'dragonfly' ]] then
		sed \
			--in-place \
			's/-Xlinker -rpath/-Xlinker -z -Xlinker origin -Xlinker -rpath/g' \
			"${workdir}/submodules/obggcc/patches/0007-Add-relative-RPATHs-to-GCC-host-tools.patch"
	fi
	
	patch --directory="${gcc_directory}" --strip='1' --input="${workdir}/patches/0001-Add-support-for-the-Android-operating-system.patch"
	patch --directory="${gcc_directory}" --strip='1' --input="${workdir}/patches/0001-Add-version-guards-for-some-libstdc-header-definitions.patch"
	patch --directory="${gcc_directory}" --strip='1' --input="${workdir}/patches/0001-Force-disable-TLS-support-in-libstdc.patch"
	
	patch --directory="${gcc_directory}" --strip='1' --input="${workdir}/patches/0001-Avoid-relying-on-dynamic-shadow-when-building-libsan.patch"
	patch --directory="${gcc_directory}" --strip='1' --input="${workdir}/patches/0001-Skip-FILE64_FLAGS-for-Android-MIPS-targets.patch"
	patch --directory="${gcc_directory}" --strip='1' --input="${workdir}/patches/0001-Disable-SONAME-versioning-for-all-target-libraries.patch"
	# patch --directory="${gcc_directory}" --strip='1' --input="${workdir}/patches/0001-Add-relative-RPATHs-to-GCC-target-libraries.patch"
	patch --directory="${gcc_directory}" --strip='1' --input="${workdir}/patches/0001-Change-GCC-s-C-standard-library-name-to-libestdc.patch"
	patch --directory="${gcc_directory}" --strip='1' --input="${workdir}/patches/0001-Rename-GCC-s-libgcc-library-to-libegcc.patch"
	patch --directory="${gcc_directory}" --strip='1' --input="${workdir}/patches/0001-Ignore-pragma-weak-when-the-declaration-is-private-o.patch"
	
	patch --directory="${gcc_directory}" --strip='1' --input="${workdir}/submodules/obggcc/patches/0001-Turn-Wimplicit-function-declaration-back-into-an-warning.patch"
	patch --directory="${gcc_directory}" --strip='1' --input="${workdir}/submodules/obggcc/patches/0002-Fix-libsanitizer-build-on-older-platforms.patch"
	patch --directory="${gcc_directory}" --strip='1' --input="${workdir}/submodules/obggcc/patches/0003-Change-the-default-language-version-for-C-compilation-from-std-gnu23-to-std-gnu17.patch"
	patch --directory="${gcc_directory}" --strip='1' --input="${workdir}/submodules/obggcc/patches/0004-Turn-Wimplicit-int-back-into-an-warning.patch"
	patch --directory="${gcc_directory}" --strip='1' --input="${workdir}/submodules/obggcc/patches/0005-Turn-Wint-conversion-back-into-an-warning.patch"
	patch --directory="${gcc_directory}" --strip='1' --input="${workdir}/submodules/obggcc/patches/0006-Turn-Wincompatible-pointer-types-back-into-an-warning.patch"
	patch --directory="${gcc_directory}" --strip='1' --input="${workdir}/submodules/obggcc/patches/0007-Add-relative-RPATHs-to-GCC-host-tools.patch"
	patch --directory="${gcc_directory}" --strip='1' --input="${workdir}/submodules/obggcc/patches/0001-AArch64-enable-libquadmath.patch"
	patch --directory="${gcc_directory}" --strip='1' --input="${workdir}/submodules/obggcc/patches/0001-Prevent-libstdc-from-trying-to-implement-math-stubs.patch"
	
	patch --directory="${gcc_directory}" --strip='1' --input="${workdir}/patches/0001-Enable-automatic-linking-of-libandroid-stb.patch"
	
	cd "${gcc_directory}"
	autoreconf
fi

# Follow Debian's approach to remove hardcoded RPATHs from binaries
# https://wiki.debian.org/RpathIssue
sed \
	--in-place \
	--regexp-extended \
	's/(hardcode_into_libs)=.*$/\1=no/' \
	"${isl_directory}/configure" \
	"${mpc_directory}/configure" \
	"${mpfr_directory}/configure" \
	"${gmp_directory}/configure" \
	"${gcc_directory}/libsanitizer/configure"

# Avoid using absolute hardcoded install_name values on macOS
sed \
	--in-place \
	's|-install_name \\$rpath/\\$soname|-install_name @rpath/\\$soname|g' \
	"${isl_directory}/configure" \
	"${mpc_directory}/configure" \
	"${mpfr_directory}/configure" \
	"${gmp_directory}/configure"

# Force GCC and binutils to prefix host tools with the target triplet even in native builds
sed \
	--in-place \
	's/test "$host_noncanonical" = "$target_noncanonical"/false/' \
	"${gcc_directory}/configure" \
	"${binutils_directory}/configure"

declare disable_assembly='--disable-assembly'

if [[ "${host}" != 'mips64el-'* ]]; then
	disable_assembly=''
fi

[ -d "${gmp_directory}/build" ] || mkdir "${gmp_directory}/build"

cd "${gmp_directory}/build"

../configure \
	--build="${build}" \
	--host="${host}" \
	--prefix="${toolchain_directory}" \
	--enable-shared \
	--disable-static \
	${disable_assembly} \
	CFLAGS="${ccflags}" \
	CXXFLAGS="${ccflags}" \
	LDFLAGS="${linkflags}"

make all --jobs
make install

[ -d "${mpfr_directory}/build" ] || mkdir "${mpfr_directory}/build"

cd "${mpfr_directory}/build"

../configure \
	--host="${host}" \
	--prefix="${toolchain_directory}" \
	--with-gmp="${toolchain_directory}" \
	--enable-shared \
	--disable-static \
	CFLAGS="${ccflags} -DMPFR_LCONV_DPTS=0" \
	CXXFLAGS="${ccflags}" \
	LDFLAGS="${linkflags}"

make all --jobs
make install

[ -d "${mpc_directory}/build" ] || mkdir "${mpc_directory}/build"

cd "${mpc_directory}/build"

../configure \
	--host="${host}" \
	--prefix="${toolchain_directory}" \
	--with-gmp="${toolchain_directory}" \
	--enable-shared \
	--disable-static \
	CFLAGS="${ccflags}" \
	CXXFLAGS="${ccflags}" \
	LDFLAGS="${linkflags}"

make all --jobs
make install

[ -d "${isl_directory}/build" ] || mkdir "${isl_directory}/build"

cd "${isl_directory}/build"
rm --force --recursive ./*

declare isl_ldflags=''

if [[ "${host}" != *'-darwin'* ]]; then
	isl_ldflags+=" -Xlinker -rpath-link -Xlinker ${toolchain_directory}/lib"
fi

../configure \
	--host="${host}" \
	--prefix="${toolchain_directory}" \
	--with-gmp-prefix="${toolchain_directory}" \
	--enable-shared \
	--disable-static \
	--with-pic \
	CFLAGS="${ccflags}" \
	CXXFLAGS="${ccflags}" \
	LDFLAGS="${linkflags} ${isl_ldflags}"

make all --jobs
make install

[ -d "${zlib_directory}/build" ] || mkdir "${zlib_directory}/build"

cd "${zlib_directory}/build"
rm --force --recursive ./*

cmake \
	-S "${zlib_directory}" \
	-B "${PWD}" \
	-DCMAKE_INSTALL_PREFIX="${toolchain_directory}" \
	-DCMAKE_PLATFORM_NO_VERSIONED_SONAME='ON' \
	-DZLIB_BUILD_TESTING='OFF'

cmake --build "${PWD}" -- --jobs
cmake --install "${PWD}" --strip

[ -d "${yasm_directory}/build" ] || mkdir "${yasm_directory}/build"

cd "${yasm_directory}/build"

../configure \
	--host="${host}" \
	--prefix="${toolchain_directory}" \
	--enable-shared \
	--disable-static \
	CFLAGS="${ccflags}" \
	CXXFLAGS="${ccflags}" \
	LDFLAGS="${linkflags}"

make all --jobs
make install

[ -d "${zstd_directory}/.build" ] || mkdir "${zstd_directory}/.build"

cd "${zstd_directory}/.build"
rm --force --recursive ./*

cmake \
	-S "${zstd_directory}/build/cmake" \
	-B "${PWD}" \
	-DCMAKE_C_FLAGS="-DZDICT_QSORT=ZDICT_QSORT_MIN ${ccflags}" \
	-DCMAKE_INSTALL_PREFIX="${toolchain_directory}" \
	-DCMAKE_BUILD_TYPE='Release' \
	-DBUILD_SHARED_LIBS=ON \
	-DZSTD_BUILD_PROGRAMS=OFF \
	-DZSTD_BUILD_TESTS=OFF \
	-DZSTD_BUILD_STATIC=OFF \
	-DCMAKE_PLATFORM_NO_VERSIONED_SONAME=ON

cmake --build "${PWD}"
cmake --install "${PWD}" --strip

[ -d "${ninja_directory}/build" ] || mkdir "${ninja_directory}/build"

cd "${ninja_directory}/build"
rm --force --recursive ./*

CMAKE_TOOLCHAIN_FILE="${CMAKE_TOOLCHAIN_FILE/21/28}" \
	cmake \
	-S "${ninja_directory}" \
	-B "${PWD}" \
	-DBUILD_TESTING='OFF' \
	-DCMAKE_POLICY_VERSION_MINIMUM='3.5' \
	-DCMAKE_INSTALL_PREFIX="${toolchain_directory}" \
	-DCMAKE_INSTALL_RPATH='$ORIGIN/../lib'

cmake --build "${PWD}"
cmake --install "${PWD}" --strip

[ -d "${patchelf_directory}/build" ] || mkdir "${patchelf_directory}/build"

cd "${patchelf_directory}/build"
rm --force --recursive ./*

cmake \
	-S "${patchelf_directory}" \
	-B "${PWD}" \
	-DCMAKE_INSTALL_PREFIX="${toolchain_directory}" \
	-DCMAKE_INSTALL_RPATH='$ORIGIN/../lib'

cmake --build "${PWD}"
cmake --install "${PWD}" --strip

[ -d "${elf_cleaner_directory}/build" ] || mkdir "${elf_cleaner_directory}/build"

cd "${elf_cleaner_directory}/build"
rm --force --recursive ./*

cmake \
	-S "${elf_cleaner_directory}" \
	-B "${PWD}" \
	-DCMAKE_INSTALL_PREFIX="${toolchain_directory}" \
	-DCMAKE_INSTALL_RPATH='$ORIGIN/../lib'

cmake --build "${PWD}"
cmake --install "${PWD}" --strip

[ -d "${gold_directory}/build" ] || mkdir "${gold_directory}/build"

cd "${gold_directory}/build"

../configure \
	--host="${host}" \
	--target='arm-linux-gnueabi' \
	--prefix="${toolchain_directory}" \
	--enable-gold \
	--enable-lto \
	--enable-separate-code \
	--enable-rosegment \
	--enable-relro \
	--enable-compressed-debug-sections='all' \
	--enable-default-compressed-debug-sections-algorithm='zstd' \
	--disable-binutils \
	--disable-gas \
	--without-static-standard-libraries \
	--with-zstd="${toolchain_directory}" \
	--with-system-zlib \
	CFLAGS="-I${toolchain_directory}/include ${ccflags}" \
	CXXFLAGS="-I${toolchain_directory}/include ${ccflags}" \
	LDFLAGS="-L${toolchain_directory}/lib ${linkflags}"

make all --jobs

mkdir --parent "${toolchain_directory}/bin"

mv "${PWD}/gold/ld-new${exe}" "${toolchain_directory}/bin/ld.gold${exe}"
mv "${PWD}/gold/dwp${exe}" "${toolchain_directory}/bin/dwp${exe}"

if (( build_nz )); then
	[ -d "${nz_directory}/build" ] || mkdir "${nz_directory}/build"
	
	cd "${nz_directory}/build"
	rm --force --recursive ./*
	
	cmake \
		-S "${nz_directory}" \
		-B "${PWD}" \
		-DCMAKE_C_FLAGS="${ccflags}" \
		-DCMAKE_CXX_FLAGS="${ccflags}" \
		-DCMAKE_INSTALL_PREFIX="${nz_prefix}"
	
	cmake --build "${PWD}" -- --jobs='1'
	cmake --install "${PWD}" --strip
	
	mkdir --parent "${toolchain_directory}/lib/nouzen"
	mv "${nz_prefix}/lib/"* "${toolchain_directory}/lib/nouzen"
	rmdir "${nz_prefix}/lib"
fi

sed \
	--in-place \
	--regexp-extended \
	"s/(GCC_MAJOR_VERSION\[\] = )\"[0-9]+\"/\1\"${gcc_major}\"/g" \
	"${workdir}/submodules/obggcc/tools/gcc-wrapper/gcc.c"

sed \
	--in-place \
	--regexp-extended \
	's/description = .*/description = "A GCC cross-compiler targeting Android",/' \
	"${workdir}/submodules/obggcc/tools/program-help.h.py"

sed \
	--in-place \
	's/--obggcc/--pino/' \
	"${workdir}/submodules/obggcc/tools/gcc-wrapper/obggcc.h"

make \
	-C "${workdir}/submodules/obggcc/tools/gcc-wrapper" \
	PREFIX="$(dirname "${gcc_wrapper}")" \
	CFLAGS="${ccflags}" \
	CXXFLAGS="${ccflags}" \
	LDFLAGS="${linkflags}" \
	FLAVOR='PINO' \
	all

# We prefer symbolic links over hard links.
cp "${workdir}/submodules/obggcc/tools/ln.sh" "${build_directory}/ln"

if [[ "${host}" = 'arm'*'-android'* ]] || [[ "${host}" = 'i686-'*'-android'* ]] || [[ "${host}" = 'mipsel-'*'-android'* ]]; then
	export \
		ac_cv_func_fseeko='no' \
		ac_cv_func_ftello='no'
fi

if [[ "${host}" = 'arm'*'-android'* ]]; then
	export PINO_ARM_MODE='true'
fi

if [[ "${host}" = *'-haiku' ]]; then
	export ac_cv_c_bigendian='no'
fi

declare cc='gcc'
declare readelf='readelf'

if ! (( native )); then
	cc="${CC}"
	readelf="${READELF}"
fi

declare url='https://github.com/AmanoTeam/android-gcc-cross/releases/download/sysroot/lib.tar.xz'
declare tarball="${build_directory}/sysroot.tar.xz"

echo "Fetching system root from '${url}'"
	
curl \
	--url "${url}" \
	--retry '30' \
	--retry-delay '0' \
	--retry-all-errors \
	--retry-max-time '0' \
	--location \
	--silent \
	--output "${tarball}"

tar \
	--directory="${toolchain_directory}" \
	--extract \
	--file="${tarball}"

url='https://github.com/AmanoTeam/android-gcc-cross/releases/download/sysroot/include.tar.xz'

echo "Fetching system root from '${url}'"
	
curl \
	--url "${url}" \
	--retry '30' \
	--retry-delay '0' \
	--retry-all-errors \
	--retry-max-time '0' \
	--location \
	--silent \
	--output "${tarball}"

tar \
	--directory="$(dirname "${bionic_headers}")" \
	--extract \
	--file="${tarball}"

for triplet in "${targets[@]}"; do
	declare extra_configure_flags=''
	declare extra_binutils_flags=''
	declare base_version='14'
	declare abi64='0'
	declare hash_style='both'
	
	enable_libsanitizer='--enable-libsanitizer'
	enable_libgcobol=''
	
	ln \
		--symbolic \
		--relative \
		--force \
		"${bionic_headers}" \
		"${toolchain_directory}/${triplet}"
	
	if [ "${triplet}" = 'riscv64-unknown-linux-android' ] || [ "${triplet}" = 'aarch64-unknown-linux-android' ] || [ "${triplet}" = 'x86_64-unknown-linux-android' ] || [ "${triplet}" = 'mips64el-unknown-linux-android' ]; then
		abi64='1'
	fi
	
	if [ "${triplet}" = 'riscv64-unknown-linux-android' ]; then
		base_version='36'
	fi
	
	if [ "${triplet}" = 'aarch64-unknown-linux-android' ] || [ "${triplet}" = 'x86_64-unknown-linux-android' ] || [ "${triplet}" = 'mips64el-unknown-linux-android' ]; then
		base_version='21'
	fi
	
	touch "${toolchain_directory}/${triplet}/lib/libandroid-stb.a"
	
	echo 'INPUT(libc.so)' > "${toolchain_directory}/${triplet}/lib/libpthread.so"
	echo 'INPUT(libc.a)' > "${toolchain_directory}/${triplet}/lib/libpthread.a"
	
	if [ "${triplet}" = 'mipsel-unknown-linux-android' ] || [ "${triplet}" = 'mips64el-unknown-linux-android' ]; then
		hash_style='sysv'
	fi
	
	if [ "${triplet}" = 'armv7-unknown-linux-androideabi' ]; then
		extra_configure_flags+=' --with-arch=armv7-a --with-float=softfp --with-fpu=vfpv3-d16 --with-mode=thumb'
	elif [ "${triplet}" = 'armv5-unknown-linux-androideabi' ]; then
		extra_configure_flags+=' --with-arch=armv5te --with-tune=xscale --with-float=soft --with-fpu=vfpv2 --with-mode=thumb'
	elif [ "${triplet}" = 'aarch64-unknown-linux-android' ]; then
		extra_configure_flags+='--with-arch=armv8-a --with-abi=lp64 --enable-fix-cortex-a53-835769 --enable-fix-cortex-a53-843419'
	elif [ "${triplet}" = 'i686-unknown-linux-android' ]; then
		extra_configure_flags+=' --with-arch=i686 --with-tune=intel --with-fpmath=sse'
	elif [ "${triplet}" = 'x86_64-unknown-linux-android' ]; then
		extra_configure_flags+=' --with-arch=x86-64 --with-tune=intel --with-fpmath=sse'
	elif [ "${triplet}" = 'riscv64-unknown-linux-android' ]; then
		extra_configure_flags+=' --with-arch=rv64gc --with-abi=lp64d --with-tls=desc'
	elif [ "${triplet}" = 'mipsel-unknown-linux-android' ]; then
		extra_configure_flags+=' --with-arch=mips32r2 --with-abi=32 --with-float=hard --with-llsc --without-synci --with-nan=legacy'
	elif [ "${triplet}" = 'mips64el-unknown-linux-android' ]; then
		extra_configure_flags+=' --with-arch=mips64r6 --with-abi=64 --with-float=hard --with-llsc --with-synci --with-nan=2008'
	fi
	
	if (( base_version >= 21 )); then
		extra_configure_flags+=' --enable-default-pie'
	fi
	
	[ -d "${binutils_directory}/build" ] || mkdir "${binutils_directory}/build"
	
	cd "${binutils_directory}/build"
	rm --force --recursive ./*
	
	../configure \
		--host="${host}" \
		--target="${triplet}" \
		--prefix="${toolchain_directory}" \
		--enable-gold \
		--enable-ld \
		--enable-lto \
		--enable-compressed-debug-sections='all' \
		--enable-default-compressed-debug-sections-algorithm='zstd' \
		--disable-gprofng \
		--without-static-standard-libraries \
		--with-sysroot="${toolchain_directory}/${triplet}" \
		--with-zstd="${toolchain_directory}" \
		--with-system-zlib \
		${extra_binutils_flags} \
		CFLAGS="-I${toolchain_directory}/include ${ccflags}" \
		CXXFLAGS="-I${toolchain_directory}/include ${ccflags}" \
		LDFLAGS="-L${toolchain_directory}/lib ${linkflags}"
	
	make all --jobs="${max_jobs}"
	make install
	
	ln \
		--symbolic \
		--relative \
		--force \
		"${toolchain_directory}/bin/ld.gold${exe}" \
		"${toolchain_directory}/bin/${triplet}-ld.gold${exe}"
	
	ln \
		--symbolic \
		--relative \
		--force \
		"${toolchain_directory}/bin/dwp${exe}" \
		"${toolchain_directory}/bin/${triplet}-dwp${exe}"
	
	touch \
		"${toolchain_directory}/${triplet}/bin/ld.gold${exe}" \
		"${toolchain_directory}/${triplet}/bin/dwp${exe}"
	
	for bin in "${toolchain_directory}/${triplet}/bin/"*; do
		unlink "${bin}"
		cp "${binutils_gnu_wrapper}" "${bin}"
	done
	
	declare specs=''
	
	specs+=' %{!Wno-complain-wrong-lang: %{!Wcomplain-wrong-lang: -Wno-complain-wrong-lang}}'
	specs+=' %{!Wno-psabi: %{!Wpsabi: -Wno-psabi}}'
	specs+=' %{!Qy: -Qn}'
	
	specs="$(xargs <<< "${specs}")"
	
	if ! (( native )); then
		extra_configure_flags+=" --with-cross-host=${host}"
		extra_configure_flags+=" --with-toolexeclibdir=${toolchain_directory}/${triplet}/lib/"
	fi
	
	if [[ "${host}" != *'-darwin'* ]] && [[ "${host}" != *'-mingw32' ]]; then
		extra_configure_flags+=' --enable-host-bind-now'
	fi
	
	if [[ "${host}" != *'-mingw32' ]]; then
		extra_configure_flags+=' --enable-host-pie'
		extra_configure_flags+=' --enable-host-shared'
	fi
	
	if [[ "${host}" != *'-mingw32' ]]; then
		extra_configure_flags+=' --enable-plugin'
	fi
	
	[ -d "${gcc_directory}/build" ] || mkdir "${gcc_directory}/build"
	
	cd "${gcc_directory}/build"
	
	rm --force --recursive ./*
	
	../configure \
		--host="${host}" \
		--target="${triplet}" \
		--prefix="${toolchain_directory}" \
		--with-linker-hash-style="${hash_style}" \
		--with-gmp="${toolchain_directory}" \
		--with-mpc="${toolchain_directory}" \
		--with-mpfr="${toolchain_directory}" \
		--with-isl="${toolchain_directory}" \
		--with-zstd="${toolchain_directory}" \
		--with-system-zlib \
		--with-gcc-major-version-only \
		--with-sysroot="${toolchain_directory}/${triplet}" \
		--with-android-version-min="${base_version}" \
		--with-native-system-header-dir='/include' \
		--with-default-libstdcxx-abi='new' \
		--with-pic \
		--with-specs="${specs}" \
		--with-gnu-ld \
		--with-gnu-as \
		--includedir="${toolchain_directory}/${triplet}/include" \
		--enable-clocale='generic' \
		--enable-__cxa_atexit \
		--enable-cet='auto' \
		--enable-checking='release' \
		--enable-default-ssp \
		--enable-gnu-indirect-function \
		--enable-languages="${languages}" \
		--enable-libstdcxx-backtrace \
		--enable-libstdcxx-filesystem-ts \
		--enable-libstdcxx-static-eh-pool \
		--with-libstdcxx-zoneinfo='static' \
		--with-libstdcxx-lock-policy='atomic' \
		--enable-link-serialization='1' \
		--enable-linker-build-id \
		--enable-lto \
		--enable-libstdcxx-time='yes' \
		--enable-shared \
		--enable-threads='posix' \
		--enable-libstdcxx-threads \
		--enable-libssp \
		--enable-initfini-array \
		--enable-libgomp \
		--enable-libstdcxx-verbose \
		--enable-tls \
		--disable-libsanitizer \
		--disable-multilib \
		--disable-canonical-system-headers \
		--disable-win32-utf8-manifest \
		--disable-fixincludes \
		--disable-gnu-unique-object \
		--disable-libstdcxx-pch \
		--disable-werror \
		--without-static-standard-libraries \
		${extra_configure_flags} \
		LDFLAGS="-L${toolchain_directory}/lib ${linkflags}"
		
	
	declare args=''
	
	if (( native )); then
		args+="${environment}"
	fi
	
	declare target_cflags="-O2"
	declare target_cxxflags="${target_cflags} -D_ABIN32=2"
	
	env ${args} make \
		CFLAGS_FOR_TARGET="${target_cflags}" \
		CXXFLAGS_FOR_TARGET="${target_cxxflags}" \
		LDFLAGS_FOR_TARGET="${linkflags}" \
		gcc_cv_objdump="${host}-objdump" \
		all --jobs="${max_jobs}"
	env ${args} make install
	
	make -C "${workdir}/tools/stubs" clean
	env ${args} make -C "${workdir}/tools/stubs" CC="${triplet}-gcc"
	
	cp "${workdir}/tools/stubs/lib"*'.a' "${toolchain_directory}/${triplet}/lib"
	
	unlink "${toolchain_directory}/${triplet}/include"
	
	cp "${workdir}/submodules/obggcc/tools/pkg-config.sh" "${toolchain_directory}/bin/${triplet}-pkg-config"
	sed --in-place 's/OBGGCC/PINO/g' "${toolchain_directory}/bin/${triplet}-pkg-config"
	
	rm "${toolchain_directory}/bin/${triplet}-${triplet}-"* 2>/dev/null || true
	
	if [[ "${host}" = *'-mingw32' ]]; then
		cp \
			"${toolchain_directory}/libexec/gcc/${triplet}/${gcc_major}/liblto_plugin${dll}" \
			"${toolchain_directory}/lib/bfd-plugins"
	else
		ln \
			--symbolic \
			--relative \
			--force \
			"${toolchain_directory}/libexec/gcc/${triplet}/${gcc_major}/liblto_plugin${dll}" \
			"${toolchain_directory}/lib/bfd-plugins"
	fi
	
	cd "${toolchain_directory}/${triplet}/lib64" 2>/dev/null || cd "${toolchain_directory}/${triplet}/lib"
	
	if [[ "$(basename "${PWD}")" = 'lib64' ]]; then
		mv ./* '../lib' || true
		rmdir "${PWD}"
		cd '../lib'
	fi
	
	[ -f './libiberty.a' ] && unlink './libiberty.a'
	
	echo 'INPUT(libestdc++.so)' > './libstdc++.so'
	echo 'INPUT(libestdc++.a)' > './libstdc++.a'
	echo 'INPUT(libegcc.so)' > './libgcc_s.so.1'
	
	echo 'INPUT (libgcc.a libgcc_eh.a)' > './libunwind.a'
	echo 'INPUT (libegcc.so libgcc_eh.a)' > './libunwind.so'
	
	declare url="https://github.com/AmanoTeam/libsanitizer/releases/download/gcc-${gcc_major}/${triplet}.tar.xz"
	
	echo "- Fetching data from '${url}'"
	
	curl \
		--url "${url}" \
		--retry '30' \
		--retry-all-errors \
		--retry-delay '0' \
		--retry-max-time '0' \
		--location \
		--silent \
		--output "${libsanitizer_tarball}"
	
	tar \
		--directory="$(dirname "${libsanitizer_directory}")" \
		--extract \
		--file="${libsanitizer_tarball}" || true
	
	cp --recursive "${libsanitizer_directory}/lib/gcc" "${toolchain_directory}/lib" || true
	cp --recursive "${libsanitizer_directory}/lib/lib"* "${toolchain_directory}/${triplet}/lib" || true
	
	rm --force --recursive "${libsanitizer_directory}"
	
	for version in "${versions[@]}"; do
		declare sysroot_directory="${toolchain_directory}/${triplet}${version}"
		
		[ -d "${sysroot_directory}" ] || continue
		
		cd "${sysroot_directory}/lib"
		mkdir "${sysroot_directory}/lib/"{gcc,static}
		
		rm --force "${toolchain_directory}/${triplet}${version}/lib/"lib{c,dl,m,z}.a
		
		echo 'INPUT(libc.so)' > "${toolchain_directory}/${triplet}${version}/lib/libpthread.so"
		echo 'INPUT(libc.a)' > "${toolchain_directory}/${triplet}${version}/lib/libpthread.a"
		
		ln \
			--symbolic \
			--relative \
			--force \
			"${toolchain_directory}/${triplet}/lib/"lib{c,dl,m,z}.a \
			"${toolchain_directory}/${triplet}${version}/lib"
		
		ln \
			--symbolic \
			--relative \
			--force \
			"${toolchain_directory}/${triplet}${version}/lib/"*.{a,so,o} \
			"${toolchain_directory}/${triplet}${version}/lib/static"
		
		for library in "${libraries[@]}"; do
			for file in "${toolchain_directory}/${triplet}/lib/${library}"*; do
				if [[ "${file}" = *'*' ]]; then
					continue
				fi
				
				if ! ( [[ "${file}" = *'.so'* ]] || [[ "${file}" = *'.a' ]] ); then
					continue
				fi
				
				ln \
					--force \
					--symbolic \
					--relative \
					"${file}" \
					"${sysroot_directory}/lib"
				
				ln \
					--force \
					--symbolic \
					--relative \
					"${file}" \
					"${sysroot_directory}/lib/gcc"
				
				if [[ "${file}" = *'.a' ]]; then
					ln \
						--force \
						--symbolic \
						--relative \
						"${file}" \
						"${sysroot_directory}/lib/static"
				fi
			done
		done
		
		if [[ "${host}" = *'-mingw32' ]]; then
			replace_symlinks "${sysroot_directory}"
		fi
		
		cp "${gcc_wrapper}" "${toolchain_directory}/bin/${triplet}${version}-gcc${exe}"
		cp "${gcc_wrapper}" "${toolchain_directory}/bin/${triplet}${version}-g++${exe}"
		cp "${gcc_wrapper}" "${toolchain_directory}/bin/${triplet}${version}-c++${exe}"
		cp "${gcc_wrapper}" "${toolchain_directory}/bin/${triplet}${version}-clang${exe}"
		cp "${gcc_wrapper}" "${toolchain_directory}/bin/${triplet}${version}-clang++${exe}"
		
		if (( build_nz )); then
			declare termux='1'
			
			[ "${triplet}" = 'riscv64-unknown-linux-android' ] && termux='0'
			[ "${triplet}" = 'mipsel-unknown-linux-android' ] && termux='0'
			[ "${triplet}" = 'mips64el-unknown-linux-android' ] && termux='0'
			[ "${triplet}" = 'armv5-unknown-linux-androideabi' ] && termux='0'
			
			status='0'
			
			(( termux && version >= 21 )) && status='1'
			
			if (( status )); then
				if (( version > 21 && version < 24 )); then
					ln --symbolic "../../${triplet}21/lib/nouzen" './'
				elif (( version > 24 )); then
					ln --symbolic "../../${triplet}24/lib/nouzen" './'
				else
					mkdir 'nouzen'
					
					cp --recursive "${nz_prefix}/"* "${PWD}/nouzen"
					
					mkdir \
						--parent \
						"${PWD}/nouzen/lib" \
						"${PWD}/nouzen/etc/nouzen/sources.list"
					
					ln \
						--symbolic \
						--relative \
						"${toolchain_directory}/lib/nouzen/lib"* \
						"${PWD}/nouzen/lib"
					
					declare repository='https://packages.termux.dev/apt/termux-main/'
					declare release='stable'
					declare resource='main'
					declare architecture=''
					
					if (( version < 24 )); then
						repository='https://packages.termux.dev/termux-main-21/'
					fi
					
					if [ "${triplet}" = 'aarch64-unknown-linux-android' ]; then
						architecture='aarch64'
					elif [ "${triplet}" = 'armv7-unknown-linux-androideabi' ]; then
						architecture='arm'
					elif [ "${triplet}" = 'i686-unknown-linux-android' ]; then
						architecture='i686'
					elif [ "${triplet}" = 'x86_64-unknown-linux-android' ]; then
						architecture='x86_64'
					else
						architecture='none'
					fi
					
					cp "${nz_directory}/options.conf" "${PWD}/nouzen/etc/nouzen"
					
					echo -e "repository = ${repository}\nrelease = ${release}\nresource = ${resource}\narchitecture = ${architecture}\nformat = apt" > './nouzen/etc/nouzen/sources.list/android-gcc-cross.conf'
					
					sed \
						--in-place \
						's|symlink-prefix = none|symlink-prefix = data/data/com.termux/files|g' \
						"${PWD}/nouzen/etc/nouzen/options.conf"
				fi
			fi
			
			if (( status )); then
				mkdir '../bin' || true
				ln --symbolic --relative './nouzen/bin/'* '../bin' || true
				ln --symbolic --relative "${toolchain_directory}/${triplet}${version}/bin/nz" "${toolchain_directory}/bin/${triplet}${version}-nz" || true
				ln --symbolic --relative "${toolchain_directory}/${triplet}${version}/bin/apt" "${toolchain_directory}/bin/${triplet}${version}-apt" || true
				ln --symbolic --relative "${toolchain_directory}/${triplet}${version}/bin/apt-get" "${toolchain_directory}/bin/${triplet}${version}-apt-get" || true
			fi
		fi
	done
	
	if [[ "${host}" = *'-mingw32' ]]; then
		replace_symlinks "${toolchain_directory}/${triplet}"
	fi
done

cp "${gcc_wrapper}" "${toolchain_directory}/bin/clang${exe}"
cp "${gcc_wrapper}" "${toolchain_directory}/bin/clang++${exe}"
cp "${binutils_llvm_wrapper}" "${toolchain_directory}/bin/llvm-strip${exe}"
cp "${binutils_llvm_wrapper}" "${toolchain_directory}/bin/llvm-objcopy${exe}"

if [[ "${host}" = *'-mingw32' ]]; then
	cp "${workdir}/tools/ndk-patch.bat" "${toolchain_directory}/bin"
else
	cp "${workdir}/tools/ndk-patch.sh" "${toolchain_directory}/bin/ndk-patch"
fi

# Delete libtool files and other unnecessary files GCC installs
rm \
	--force \
	--recursive \
	"${toolchain_directory}/share" \
	"${toolchain_directory}/lib/lib"*'.a' \
	"${toolchain_directory}/lib/pkgconfig" \
	"${toolchain_directory}/lib/cmake" \
	"${toolchain_directory}/include"

mv "${bionic_headers}" "${toolchain_directory}"

for directory in "${toolchain_directory}/"*'-linux-android'*; do
	unlink "${directory}/include" || true
	
	ln \
		--symbolic \
		--relative \
		"${toolchain_directory}/include" \
		"${directory}"
done

sed \
	--in-place \
	's|#define _GLIBCXX_HAVE_TLS 1|/* #undef _GLIBCXX_HAVE_TLS */|g' \
	"${toolchain_directory}/include/c++/${gcc_major}/"*'-unknown-linux-android'*'/bits/c++config.h'

find \
	"${toolchain_directory}" \
	-name '*.la' -delete -o \
	-name '*.py' -delete -o \
	-name '*.json' -delete

cd "${workdir}"

# Bundle both libstdc++ and libgcc within host tools
if ! (( native )) && [[ "${host}" != *'-darwin'* ]]; then
	[ -d "${toolchain_directory}/lib" ] || mkdir "${toolchain_directory}/lib"
	
	# libestdc++
	declare name=$(realpath $("${cc}" --print-file-name="libestdc++${dll}"))
	
	# libstdc++
	if ! [ -f "${name}" ]; then
		declare name=$(realpath $("${cc}" --print-file-name="libstdc++${dll}"))
	fi
	
	declare soname=''
	
	if [[ "${host}" != *'-mingw32' ]]; then
		soname=$("${readelf}" -d "${name}" | grep 'SONAME' | sed --regexp-extended 's/.+\[(.+)\]/\1/g')
	fi
	
	cp "${name}" "${toolchain_directory}/lib/${soname}"
	
	if [[ "${host}" = *'-mingw32' ]]; then
		cp "${name}" "${toolchain_directory}/bin/${soname}"
	fi
	
	if (( build_nz )); then
		ln \
			--symbolic \
			--relative \
			"${toolchain_directory}/lib/${soname}" \
			"${toolchain_directory}/lib/nouzen"
	fi
	
	# libegcc
	declare name=$(realpath $("${cc}" --print-file-name="libegcc${dll}"))
	
	if ! [ -f "${name}" ]; then
		# libgcc_s
		declare name=$(realpath $("${cc}" --print-file-name="libgcc_s${dll}.1"))
	fi
	
	if [[ "${host}" = *'-mingw32' ]]; then
		if ! [ -f "${name}" ]; then
			# libgcc_s_seh
			declare name=$(realpath $("${cc}" --print-file-name="libgcc_s_seh${dll}"))
		fi
		
		if ! [ -f "${name}" ]; then
			# libgcc_s_sjlj
			declare name=$(realpath $("${cc}" --print-file-name="libgcc_s_sjlj${dll}"))
		fi
	fi
	
	if [[ "${host}" != *'-mingw32' ]]; then
		soname=$("${readelf}" -d "${name}" | grep 'SONAME' | sed --regexp-extended 's/.+\[(.+)\]/\1/g')
	fi
	
	cp "${name}" "${toolchain_directory}/lib/${soname}"
	
	if [[ "${host}" = *'-mingw32' ]]; then
		cp "${name}" "${toolchain_directory}/bin/${soname}"
	fi
	
	if (( build_nz )); then
		ln \
			--symbolic \
			--relative \
			"${toolchain_directory}/lib/${soname}" \
			"${toolchain_directory}/lib/nouzen"
	fi
	
	# libatomic
	declare name=$(realpath $("${cc}" --print-file-name="libatomic${dll}"))
	
	if [[ "${host}" != *'-mingw32' ]]; then
		soname=$("${readelf}" -d "${name}" | grep 'SONAME' | sed --regexp-extended 's/.+\[(.+)\]/\1/g')
	fi
	
	cp "${name}" "${toolchain_directory}/lib/${soname}"
	
	if [[ "${host}" = *'-mingw32' ]]; then
		cp "${name}" "${toolchain_directory}/bin/${soname}"
	fi
	
	if (( build_nz )); then
		ln \
			--symbolic \
			--relative \
			"${toolchain_directory}/lib/${soname}" \
			"${toolchain_directory}/lib/nouzen"
	fi
	
	# libiconv
	declare name=$(realpath $("${cc}" --print-file-name="libiconv${dll}"))
	
	if [ -f "${name}" ]; then
		if [[ "${host}" != *'-mingw32' ]]; then
			soname=$("${readelf}" -d "${name}" | grep 'SONAME' | sed --regexp-extended 's/.+\[(.+)\]/\1/g')
		fi
		
		cp "${name}" "${toolchain_directory}/lib/${soname}"
		
		if [[ "${host}" = *'-mingw32' ]]; then
			cp "${name}" "${toolchain_directory}/bin/${soname}"
		fi
		
		if (( build_nz )); then
			ln \
				--symbolic \
				--relative \
				"${toolchain_directory}/lib/${soname}" \
				"${toolchain_directory}/lib/nouzen"
		fi
	fi
	
	# libcharset
	declare name=$(realpath $("${cc}" --print-file-name="libcharset${dll}"))
	
	if [ -f "${name}" ]; then
		if [[ "${host}" != *'-mingw32' ]]; then
			soname=$("${readelf}" -d "${name}" | grep 'SONAME' | sed --regexp-extended 's/.+\[(.+)\]/\1/g')
		fi
		
		cp "${name}" "${toolchain_directory}/lib/${soname}"
		
		if [[ "${host}" = *'-mingw32' ]]; then
			cp "${name}" "${toolchain_directory}/bin/${soname}"
		fi
		
		if (( build_nz )); then
			ln \
				--symbolic \
				--relative \
				"${toolchain_directory}/lib/${soname}" \
				"${toolchain_directory}/lib/nouzen"
		fi
	fi
	
	if [[ "${host}" = *'-mingw32' ]]; then
		# libwinpthread
		declare name=$(realpath $("${cc}" --print-file-name="libwinpthread${dll}"))
		cp "${name}" "${toolchain_directory}/bin/${soname}"
	fi
	
	if [[ "${host}" = *'-mingw32' ]]; then
		for target in "${targets[@]}"; do
			for source in "${toolchain_directory}/"{bin,lib}"/lib"*'.dll'; do
				cp "${source}" "${toolchain_directory}/libexec/gcc/${target}/${gcc_major}"
			done
		done
		
		rm "${toolchain_directory}/lib/lib"*'.'{dll,lib}
	fi
fi

mkdir --parent "${share_directory}"

cp --recursive "${workdir}/tools/dev/"* "${share_directory}"

[ -d "${toolchain_directory}/build" ] || mkdir "${toolchain_directory}/build"

ln \
	--symbolic \
	--relative \
	"${share_directory}/"* \
	"${toolchain_directory}/build"
