#!/usr/bin/env bash

set -eu

declare -r debian_sysroot_tarball='/tmp/sysroot.tar.xz'

declare -r mipsel_sysroot='/tmp/mipsel-unknown-linux-gnu2.31'
declare -r mips64_sysroot='/tmp/mips64el-unknown-linux-gnuabi642.31'

declare -ra targets=(
	'aarch64-unknown-linux-android'
	# 'riscv64-unknown-linux-android'
	'armv7-unknown-linux-androideabi'
	# 'armv5-unknown-linux-androideabi'
	'x86_64-unknown-linux-android'
	'i686-unknown-linux-android'
	# 'mipsel-unknown-linux-android'
	# 'mips64el-unknown-linux-android'
)

declare -r versions=(
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
	'37'
)

declare -r ANDROID_NDK_VERSION='r30'

declare -r ndk_archive='/tmp/ndk.zip'
declare -r ndk_directory="/tmp/android-ndk-${ANDROID_NDK_VERSION}"
declare -r bionic_directory='/tmp/bionic'
declare -r unsupported_ndk_directory='/tmp/android-ndk-r16b'

declare -r include_dir="${ndk_directory}/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/include"

declare -r workdir="${PWD}"

function get_arch() {
	
	if [ "${1}" = 'aarch64-unknown-linux-android' ]; then
		echo 'arm64'
	fi
	
	if [ "${1}" = 'riscv64-unknown-linux-android' ]; then
		echo 'riscv64'
	fi
	
	if [ "${1}" = 'arm-unknown-linux-androideabi' ]; then
		echo 'arm'
	fi
	
	if [ "${1}" = 'armv5-unknown-linux-androideabi' ]; then
		echo 'arm'
	fi
	
	if [ "${1}" = 'armv7-unknown-linux-androideabi' ]; then
		echo 'arm'
	fi
	
	if [ "${1}" = 'x86_64-unknown-linux-android' ]; then
		echo 'x86_64'
	fi
	
	if [ "${1}" = 'i686-unknown-linux-android' ]; then
		echo 'x86'
	fi
	
	if [ "${1}" = 'mipsel-unknown-linux-android' ]; then
		echo 'mips'
	fi
	
	if [ "${1}" = 'mips64el-unknown-linux-android' ]; then
		echo 'mips64'
	fi

}

if ! [ -f "${ndk_archive}" ]; then
	curl \
		--url "https://dl.google.com/android/repository/android-ndk-${ANDROID_NDK_VERSION}-linux.zip" \
		--retry '30' \
		--retry-all-errors \
		--retry-delay '0' \
		--retry-max-time '0' \
		--location \
		--silent \
		--output "${ndk_archive}"
	
	unzip \
		-d "$(dirname "${ndk_directory}")" \
		-q \
		"${ndk_archive}"
	
	patch \
		--directory="${include_dir}" \
		--strip='1' \
		--input="${workdir}/patches/0001-Android-NDK-headers.patch"
	
	mv "${include_dir}/sys/cdefs.h" './cdefs.h'
	
	while read file; do
		sed \
			--in-place \
			--expression 's/__INTRODUCED_IN(9)/__INTRODUCED_IN_API_G__/g; s/__INTRODUCED_IN(__ANDROID_API_G__)/__INTRODUCED_IN_API_G__/g' \
			--expression 's/__INTRODUCED_IN(14)/__INTRODUCED_IN_API_I__/g; s/__INTRODUCED_IN(__ANDROID_API_I__)/__INTRODUCED_IN_API_I__/g' \
			--expression 's/__INTRODUCED_IN(16)/__INTRODUCED_IN_API_J__/g; s/__INTRODUCED_IN(__ANDROID_API_J__)/__INTRODUCED_IN_API_J__/g' \
			--expression 's/__INTRODUCED_IN(17)/__INTRODUCED_IN_API_J_MR1__/g; s/__INTRODUCED_IN(__ANDROID_API_J_MR1__)/__INTRODUCED_IN_API_J_MR1__/g' \
			--expression 's/__INTRODUCED_IN(18)/__INTRODUCED_IN_API_J_MR2__/g; s/__INTRODUCED_IN(__ANDROID_API_J_MR2__)/__INTRODUCED_IN_API_J_MR2__/g' \
			--expression 's/__INTRODUCED_IN(19)/__INTRODUCED_IN_API_K__/g; s/__INTRODUCED_IN(__ANDROID_API_K__)/__INTRODUCED_IN_API_K__/g' \
			--expression 's/__INTRODUCED_IN(21)/__INTRODUCED_IN_API_L__/g; s/__INTRODUCED_IN(__ANDROID_API_L__)/__INTRODUCED_IN_API_L__/g' \
			--expression 's/__INTRODUCED_IN(22)/__INTRODUCED_IN_API_L_MR1__/g; s/__INTRODUCED_IN(__ANDROID_API_L_MR1__)/__INTRODUCED_IN_API_L_MR1__/g' \
			--expression 's/__INTRODUCED_IN(23)/__INTRODUCED_IN_API_M__/g; s/__INTRODUCED_IN(__ANDROID_API_M__)/__INTRODUCED_IN_API_M__/g' \
			--expression 's/__INTRODUCED_IN(24)/__INTRODUCED_IN_API_N__/g; s/__INTRODUCED_IN(__ANDROID_API_N__)/__INTRODUCED_IN_API_N__/g' \
			--expression 's/__INTRODUCED_IN(25)/__INTRODUCED_IN_API_N_MR1__/g; s/__INTRODUCED_IN(__ANDROID_API_N_MR1__)/__INTRODUCED_IN_API_N_MR1__/g' \
			--expression 's/__INTRODUCED_IN(26)/__INTRODUCED_IN_API_O__/g; s/__INTRODUCED_IN(__ANDROID_API_O__)/__INTRODUCED_IN_API_O__/g' \
			--expression 's/__INTRODUCED_IN(27)/__INTRODUCED_IN_API_O_MR1__/g; s/__INTRODUCED_IN(__ANDROID_API_O_MR1__)/__INTRODUCED_IN_API_O_MR1__/g' \
			--expression 's/__INTRODUCED_IN(28)/__INTRODUCED_IN_API_P__/g; s/__INTRODUCED_IN(__ANDROID_API_P__)/__INTRODUCED_IN_API_P__/g' \
			--expression 's/__INTRODUCED_IN(29)/__INTRODUCED_IN_API_Q__/g; s/__INTRODUCED_IN(__ANDROID_API_Q__)/__INTRODUCED_IN_API_Q__/g' \
			--expression 's/__INTRODUCED_IN(30)/__INTRODUCED_IN_API_R__/g; s/__INTRODUCED_IN(__ANDROID_API_R__)/__INTRODUCED_IN_API_R__/g' \
			--expression 's/__INTRODUCED_IN(31)/__INTRODUCED_IN_API_S__/g; s/__INTRODUCED_IN(__ANDROID_API_S__)/__INTRODUCED_IN_API_S__/g' \
			--expression 's/__INTRODUCED_IN(33)/__INTRODUCED_IN_API_T__/g; s/__INTRODUCED_IN(__ANDROID_API_T__)/__INTRODUCED_IN_API_T__/g' \
			--expression 's/__INTRODUCED_IN(34)/__INTRODUCED_IN_API_U__/g; s/__INTRODUCED_IN(__ANDROID_API_U__)/__INTRODUCED_IN_API_U__/g' \
			--expression 's/__INTRODUCED_IN(35)/__INTRODUCED_IN_API_V__/g; s/__INTRODUCED_IN(__ANDROID_API_V__)/__INTRODUCED_IN_API_V__/g' \
			--expression 's/__INTRODUCED_IN(36)/__INTRODUCED_IN_API_W__/g; s/__INTRODUCED_IN(__ANDROID_API_W__)/__INTRODUCED_IN_API_W__/g' \
			--expression 's/ __attribute__((__nomerge__))//g' \
			--expression '/#pragma clang/d' \
			"${file}"
	done <<< "$(find "${include_dir}" -type 'f')"
	
	python -B "${workdir}/tools/add_nonnull_attrs.py" "${include_dir}"
	
	python \
		-B \
		"${workdir}/tools/add_throw_attrs.py" \
		"${include_dir}" \
		"${workdir}/tools/thrown/__throw.json" \
		"${workdir}/tools/thrown/__thrownl.json" \
		"${workdir}/tools/thrown/none.json"
	
	while read file; do
		sed \
			--in-place \
			--expression 's/ _Nonnull / /g; s/ _Nonnull,/,/g; s/_Nonnull)/)/g; s/\[_Nonnull /\[/g; s/ _Nonnull\*/\*/g; s/ \*_Nonnull/\*/g; s/\[_Nonnull\]/\[\]/g; s/\*_Nonnull /\*/g; s/\* _Nonnull/\*/g' \
			--expression 's/ _Nullable / /g; s/ _Nullable,/,/g; s/_Nullable)/)/g; s/\[_Nullable /\[/g; s/ _Nullable\*/\*/g; s/ \*_Nullable/\*/g; s/\[_Nullable\]/\[\]/g; s/\*_Nullable /\*/g; s/\* _Nullable/\*/g' \
			--expression 's/ _Null_unspecified / /g; s/ _Null_unspecified,/,/g; s/_Null_unspecified)/)/g; s/\[_Null_unspecified /\[/g; s/ _Null_unspecified\*/\*/g; s/ \*_Null_unspecified/\*/g; s/\[_Null_unspecified\]/\[\]/g; s/\*_Null_unspecified /\*/g; s/\* _Null_unspecified/\*/g' \
			--expression 's/ __BIONIC_COMPLICATED_NULLNESS / /g; s/ __BIONIC_COMPLICATED_NULLNESS,/,/g; s/__BIONIC_COMPLICATED_NULLNESS)/)/g; s/\[__BIONIC_COMPLICATED_NULLNESS /\[/g; s/ __BIONIC_COMPLICATED_NULLNESS\*/\*/g; s/ \*__BIONIC_COMPLICATED_NULLNESS/\*/g; s/\[__BIONIC_COMPLICATED_NULLNESS\]/\[\]/g; s/\*__BIONIC_COMPLICATED_NULLNESS /\*/g; s/\* __BIONIC_COMPLICATED_NULLNESS/\*/g' \
			--expression 's/ __attribute__((__nomerge__))//g' \
			"${file}"
		
		sed \
			--in-place \
			--regexp-extended \
			--expression 's/\s*__THROW\s*__THROW/__THROW/g' \
			--expression 's/\s*__THROW\s*__RENAME\(([^)]*)\)/ __REDIRECT_NTH(\1)/g' \
			--expression 's/\s*__THROW\s*__RENAME_IF_FILE_OFFSET64\(([^)]*)\)/ __REDIRECT_IF_FILE_OFFSET64_NTH(\1)/g' \
			"${file}"
	done <<< "$(find "${include_dir}" -type 'f')"
	
	mv './cdefs.h' "${include_dir}/sys/cdefs.h"
	
	curl \
		--url 'https://dl.google.com/android/repository/android-ndk-r16b-linux-x86_64.zip' \
		--retry '30' \
		--retry-all-errors \
		--retry-delay '0' \
		--retry-max-time '0' \
		--location \
		--silent \
		--output "${ndk_archive}"
	
	unzip \
		-d "$(dirname "${ndk_directory}")" \
		-q \
		"${ndk_archive}"
	
	ln \
		--symbolic \
		"${unsupported_ndk_directory}/platforms/android-24" \
		"${unsupported_ndk_directory}/platforms/android-25"
	
	ln \
		--symbolic \
		"${unsupported_ndk_directory}/platforms/android-19" \
		"${unsupported_ndk_directory}/platforms/android-20"
fi

if ! [ -d "${bionic_directory}" ]; then
	git clone --depth '1' 'https://android.googlesource.com/platform/bionic' "${bionic_directory}"
fi

if ! [ -f "${debian_sysroot_tarball}" ]; then
	curl \
		--url 'https://github.com/AmanoTeam/debian-sysroot/releases/latest/download/mipsel-unknown-linux-gnu2.31.tar.xz' \
		--retry '30' \
		--retry-delay '0' \
		--retry-all-errors \
		--retry-max-time '0' \
		--location \
		--silent \
		--output "${debian_sysroot_tarball}"
	
	tar \
		--directory="$(dirname "${mipsel_sysroot}")" \
		--extract \
		--file="${debian_sysroot_tarball}"
	
	curl \
		--url 'https://github.com/AmanoTeam/debian-sysroot/releases/latest/download/mips64el-unknown-linux-gnuabi642.31.tar.xz' \
		--retry '30' \
		--retry-delay '0' \
		--retry-all-errors \
		--retry-max-time '0' \
		--location \
		--silent \
		--output "${debian_sysroot_tarball}"
	
	tar \
		--directory="$(dirname "${mips64_sysroot}")" \
		--extract \
		--file="${debian_sysroot_tarball}"
	
	sed \
		--in-place \
		's/ sigaction / __kernel_sigaction /g' \
		"${mips64_sysroot}/include/asm/signal.h" \
		"${mipsel_sysroot}/include/asm/signal.h"
	
	mkdir "${include_dir}/mips64el-linux-android"
	mkdir "${include_dir}/mipsel-linux-android"
	
	cp --recursive "${mips64_sysroot}/include/asm" "${include_dir}/mips64el-linux-android"
	cp --recursive "${mipsel_sysroot}/include/asm" "${include_dir}/mipsel-linux-android"
	
	patch \
		--directory="${include_dir}/mipsel-linux-android" \
		--strip='1' \
		--input="${workdir}/patches/0001-Rename-SIOCGSTAMP-and-SIOCGSTAMPNS.patch"
	
	patch \
		--directory="${include_dir}/mips64el-linux-android" \
		--strip='1' \
		--input="${workdir}/patches/0001-Rename-SIOCGSTAMP-and-SIOCGSTAMPNS.patch"
		
		patch \
		--directory="${include_dir}/mipsel-linux-android" \
		--strip='1' \
		--input="${workdir}/patches/0001-Avoid-declaring-struct-flock.patch"
	
	patch \
		--directory="${include_dir}/mips64el-linux-android" \
		--strip='1' \
		--input="${workdir}/patches/0001-Avoid-declaring-struct-flock.patch"
fi

rm --recursive --force "${include_dir}/c++"

for directory in "${include_dir}/"*'-linux-android'*; do
	mv "${directory}" "${directory/-linux/-unknown-linux}" 
done

mv \
	"${include_dir}/arm-unknown-linux-androideabi" \
	"${include_dir}/armv7-unknown-linux-androideabi"

ln \
	--symbolic \
	--relative \
	"${include_dir}/armv7-unknown-linux-androideabi" \
	"${include_dir}/armv5-unknown-linux-androideabi"

declare tarball_filename='/tmp/include.tar.xz'

tar \
	--directory="$(dirname "${include_dir}")" \
	--create \
	--file=- \
	"$(basename "${include_dir}")" |
		xz \
			--compress \
			-9 > "${tarball_filename}"

sha256sum "${tarball_filename}" | sed 's|/tmp/||' > "${tarball_filename}.sha256"

declare -r include_directory_old="${unsupported_ndk_directory}/sysroot/usr/include"
declare -r include_directory_new="${ndk_directory}/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/include"

mkdir '/tmp/bionic-libraries'

for target in "${targets[@]}"; do
	declare arch="$(get_arch ${target})"
	
	declare triplet="${target/-unknown/}"
	declare triplet="${triplet/armv7/arm}"
	declare triplet="${triplet/armv5/arm}"
	
	declare unsupported_ndk='0'
	
	for version in "${versions[@]}"; do
		if [ "${target}" != 'armv5-unknown-linux-androideabi' ] && [ -d "${ndk_directory}/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/${triplet}/${version}" ]; then
			unsupported_ndk='0'
		elif [ -d "${unsupported_ndk_directory}/platforms/android-${version}/arch-${arch}" ]; then
			unsupported_ndk='1'
		else
			continue
		fi
		
		echo "${target}${version} (${unsupported_ndk})"
		
		declare sysroot_directory="/tmp/bionic-libraries/${target}${version}"
		
		rm --recursive --force "${sysroot_directory}"
		
		mkdir --parent "${sysroot_directory}/lib"
		
		declare library_directory=''
		declare library_directory2=''
		
		if (( unsupported_ndk )); then
			library_directory="${unsupported_ndk_directory}/platforms/android-${version}/arch-${arch}/usr/lib"
			library_directory2="${unsupported_ndk_directory}/platforms/android-${version}/arch-${arch}/usr/lib64"
		else
			library_directory="${ndk_directory}/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/${triplet}/${version}"
			library_directory2="${ndk_directory}/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/${triplet}"
		fi
		
		if (( unsupported_ndk )); then
			cp \
				"${library_directory}/"*.so \
				"${library_directory2}/"*.so \
				"${sysroot_directory}/lib" 2>/dev/null || true
			
			cp "${ndk_directory}/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/${triplet}/"lib{c,dl,m,z}.a "${sysroot_directory}/lib" || true
		else
			cp \
				"${library_directory}/"*.a \
				"${library_directory}/"*.so \
				"${library_directory2}/"*.{a,so} \
				"${sysroot_directory}/lib" 2>/dev/null || true
		fi
		
		rm "${sysroot_directory}/lib/lib"{compiler,stdc++,c++}* 2>/dev/null || true
		# rm "${sysroot_directory}/lib/lib"*'.a'
	done
done

rm --recursive --force "${PINO_HOME}/include"
cp --recursive "${include_dir}" "${PINO_HOME}"

# Build the CRT objects with our own GCC drivers instead of reusing the NDK's
# clang-built ones, for every sysroot directory staged above.
make -C "${workdir}/tools/crt" BIONIC_DIR="${bionic_directory}" OUT='/tmp/bionic-libraries'

# Download the stub libraries' symbol files (the bionic ones come from the
# checkout; the rest live in their upstream repositories).
declare -r ndk_stub_maps="${workdir}/tools/ndk-stubs/maps"

declare -rA ndk_stub_symbol_files=(
	['libEGL']='platform/frameworks/native/+/refs/heads/main/opengl/libs/libEGL.map.txt'
	['libGLESv1_CM']='platform/frameworks/native/+/refs/heads/main/opengl/libs/libGLESv1_CM.map.txt'
	['libGLESv2']='platform/frameworks/native/+/refs/heads/main/opengl/libs/libGLESv2.map.txt'
	['libGLESv3']='platform/frameworks/native/+/refs/heads/main/opengl/libs/libGLESv3.map.txt'
	['libandroid']='platform/frameworks/base/+/refs/heads/main/native/android/libandroid.map.txt'
	['libz']='platform/external/zlib/+/refs/heads/main/libz.map.txt'
	['liblog']='platform/system/logging/+/refs/heads/main/liblog/liblog.map.txt'
	['libjnigraphics']='platform/frameworks/base/+/refs/heads/main/native/graphics/jni/libjnigraphics.map.txt'
	['libmediandk']='platform/frameworks/av/+/refs/heads/main/media/ndk/libmediandk.map.txt'
	['libOpenSLES']='platform/frameworks/wilhelm/+/refs/heads/main/src/libOpenSLES.map.txt'
	['libOpenMAXAL']='platform/frameworks/wilhelm/+/refs/heads/main/src/libOpenMAXAL.map.txt'
	['libcamera2ndk']='platform/frameworks/av/+/refs/heads/main/camera/ndk/libcamera2ndk.map.txt'
	['libvulkan']='platform/frameworks/native/+/refs/heads/main/vulkan/libvulkan/libvulkan.map.txt'
	['libaaudio']='platform/frameworks/av/+/refs/heads/main/media/libaaudio/src/libaaudio.map.txt'
	['libnativewindow']='platform/frameworks/native/+/refs/heads/main/libs/nativewindow/libnativewindow.map.txt'
	['libsync']='platform/system/core/+/refs/heads/main/libsync/libsync.map.txt'
	['libamidi']='platform/frameworks/base/+/refs/heads/main/media/native/midi/libamidi.map.txt'
	['libbinder_ndk']='platform/frameworks/native/+/refs/heads/main/libs/binder/ndk/libbinder_ndk.map.txt'
	['libneuralnetworks']='platform/packages/modules/NeuralNetworks/+/refs/heads/main/runtime/libneuralnetworks.map.txt'
	['libicu']='platform/external/icu/+/refs/heads/main/libicu/libicu.map.txt'
	['libnativehelper']='platform/libnativehelper/+/refs/heads/main/libnativehelper.map.txt'
)

mkdir --parents "${ndk_stub_maps}"

for library in "${!ndk_stub_symbol_files[@]}"; do
	if ! [ -s "${ndk_stub_maps}/${library}.map.txt" ]; then
		echo "https://android.googlesource.com/${ndk_stub_symbol_files[${library}]}?format=TEXT"
		curl \
			--url "https://android.googlesource.com/${ndk_stub_symbol_files[${library}]}?format=TEXT" \
			--retry '30' \
			--retry-all-errors \
			--retry-delay '0' \
			--retry-max-time '0' \
			--location \
			--silent \
			--show-error \
			--fail \
			--user-agent 'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:140.0) Gecko/20100101 Firefox/140.0' \
			--output "${ndk_stub_maps}/${library}.map.txt.b64"

		base64 \
			--decode \
			"${ndk_stub_maps}/${library}.map.txt.b64" > "${ndk_stub_maps}/${library}.map.txt"

		unlink "${ndk_stub_maps}/${library}.map.txt.b64"
	fi
done

# Build the stub shared libraries the same way AOSP generates them for the NDK
# (ndkstubgen + the libraries' map files), overwriting the NDK-copied ones.
make -C "${workdir}/tools/ndk-stubs" BIONIC_DIR="${bionic_directory}" OUT='/tmp/bionic-libraries'

declare tarball_filename='/tmp/lib.tar.xz'

cd '/tmp/bionic-libraries'

cp \
	--recursive \
	'aarch64-unknown-linux-android21' \
	'aarch64-unknown-linux-android'

cp \
	--recursive \
	'armv5-unknown-linux-androideabi14' \
	'armv5-unknown-linux-androideabi' || true

cp \
	--recursive \
	'armv7-unknown-linux-androideabi14' \
	'armv7-unknown-linux-androideabi'

cp \
	--recursive \
	'i686-unknown-linux-android14' \
	'i686-unknown-linux-android'

cp \
	--recursive \
	'mips64el-unknown-linux-android21' \
	'mips64el-unknown-linux-android' || true

cp \
	--recursive \
	'mipsel-unknown-linux-android14' \
	'mipsel-unknown-linux-android' || true

cp \
	--recursive \
	'riscv64-unknown-linux-android36' \
	'riscv64-unknown-linux-android' || true

cp \
	--recursive \
	'x86_64-unknown-linux-android21' \
	'x86_64-unknown-linux-android'

for target in "${targets[@]}"; do
	make -C "${workdir}/tools/stubs" clean
	make -C "${workdir}/tools/stubs" CC="${target}-gcc"
	
	cp "${workdir}/tools/stubs/lib"*'.a' "${target}/lib"
done

tar \
	--create \
	--file=- \
	*'-unknown-'* |
		xz \
			--compress \
			-9 > "${tarball_filename}"

sha256sum "${tarball_filename}" | sed 's|/tmp/||' > "${tarball_filename}.sha256"

unlink "${debian_sysroot_tarball}"

