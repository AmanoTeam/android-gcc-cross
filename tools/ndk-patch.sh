#!/bin/bash

set -eu

declare -r app_directory="$(realpath "$(( [ -n "${BASH_SOURCE}" ] && dirname "$(realpath "${BASH_SOURCE[0]}")" ) || dirname "$(realpath "${0}")")")"

declare -ra binutils=(
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

declare -ra triplets=(
	'aarch64-linux-android'
	'i686-linux-android'
	'arm-linux-androideabi'
	'x86_64-linux-android'
	'mips64el-linux-android'
	'mipsel-linux-android'
	'riscv64-linux-android'
)

declare -r os="$(uname -o)"

declare symlink_options='--symbolic --force'
declare slug='linux-x86_64'

declare fallback_sdk_root="${HOME}/Android/Sdk"

if [ "${os}" = 'Darwin' ]; then
	fallback_sdk_root="${HOME}/Library/Android/sdk"
	slug='darwin-x86_64'
	symlink_options='-s -f'
fi

set +u

declare sdk_root=''
declare ndk_root=''

declare -i symlinks=0

declare -a directories=()

function symlink() {

	ln ${symlink_options} "${1}" "${2}"
	(( symlinks += 1 ))
	
}

# Android SDK
if [ -z "${sdk_root}" ]; then
	declare sdk_root="${ANDROID_HOME}"
fi

if [ -z "${sdk_root}" ]; then
	declare sdk_root="${ANDROID_SDK_ROOT}"
fi

if [ -z "${sdk_root}" ] && [ -d "${fallback_sdk_root}" ]; then
	declare sdk_root="${fallback_sdk_root}"
fi

# Android NDK
if [ -z "${ndk_root}" ]; then
	declare ndk_root="${ANDROID_NDK_HOME}"
fi

if [ -z "${ndk_root}" ]; then
	declare ndk_root="${ANDROID_NDK_ROOT}"
fi

if [ -z "${ndk_root}" ]; then
	declare ndk_root="${NDK_HOME}"
fi

if [ -z "${ndk_root}" ]; then
	declare ndk_root="${ANDROID_NDK}"
fi

if [ -z "${ndk_root}" ]; then
	declare ndk_root="${ANDROID_NDK}"
fi

if [ -z "${ndk_root}" ]; then
	declare ndk_root="${NDK}"
fi

declare -r cmake_directory="${sdk_root}/cmake"

set -u

if [ -n "${sdk_root}" ] && [ -d "${sdk_root}" ]; then
	echo "checking ${sdk_root}"
	
	for directory in "${sdk_root}/ndk/"*; do
		if ! [ -d "${directory}" ]; then
			continue
		fi
		
		directories+=("${directory}")
	done
elif [ -n "${ndk_root}" ] && [ -d "${ndk_root}" ]; then
	echo "checking ${ndk_root}"
	
	directories+=("${ndk_root}")
else
	echo 'fatal error: unable to find SDK location: please define ANDROID_HOME or ANDROID_SDK_ROOT' >&2
	echo 'fatal error: you can also explicitly set the NDK location with ANDROID_NDK_HOME or ANDROID_NDK_ROOT' >&2
	exit '1'
fi

if [ "${#directories[@]}" -eq 0 ]; then
	echo 'nothing to do!' >&2
	exit '0'
fi

for directory in "${directories[@]}"; do
	declare source="${app_directory}/clang"
	declare destination="${directory}/toolchains/llvm/prebuilt/${slug}/bin/clang"
	
	declare toolchains_directory="${directory}/toolchains"
	
	if [[ "$(readlink "${destination}")" != "${source}" ]]; then
		echo "symlinking ${source} to ${destination}"
		symlink "${source}" "${destination}"
	fi
	
	source+='++'
	destination+='++'
	
	if [[ "$(readlink "${destination}")" != "${source}" ]]; then
		echo "symlinking ${source} to ${destination}"
		symlink "${source}" "${destination}"
	fi
	
	# yasm
	source="${source/clang++/yasm}"
	destination="${destination/clang++/yasm}"
	
	if [[ "$(readlink "${destination}")" != "${source}" ]]; then
		echo "symlinking ${source} to ${destination}"
		symlink "${source}" "${destination}"
	fi
	
	# llvm-strip
	source="${source/yasm/llvm-strip}"
	destination="${destination/yasm/llvm-strip}"
	
	if [[ "$(readlink "${destination}")" != "${source}" ]]; then
		echo "symlinking ${source} to ${destination}"
		symlink "${source}" "${destination}"
	fi
	
	# llvm-objcopy
	source="${source/llvm-strip/llvm-objcopy}"
	destination="${destination/llvm-strip/llvm-objcopy}"
	
	if [[ "$(readlink "${destination}")" != "${source}" ]]; then
		echo "symlinking ${source} to ${destination}"
		symlink "${source}" "${destination}"
	fi
	
	# llvm-ar (architecture-independent)
	source="${source/llvm-objcopy/x86_64-unknown-linux-android-ar}"
	destination="${destination/llvm-objcopy/llvm-ar}"
	
	if [[ "$(readlink "${destination}")" != "${source}" ]]; then
		echo "symlinking ${source} to ${destination}"
		symlink "${source}" "${destination}"
	fi
	
	# llvm-nm (architecture-independent)
	source="${source/-ar/-nm}"
	destination="${destination/-ar/-nm}"
	
	if [[ "$(readlink "${destination}")" != "${source}" ]]; then
		echo "symlinking ${source} to ${destination}"
		symlink "${source}" "${destination}"
	fi
	
	# llvm-ranlib (architecture-independent)
	source="${source/-nm/-ranlib}"
	destination="${destination/-nm/-ranlib}"
	
	if [[ "$(readlink "${destination}")" != "${source}" ]]; then
		echo "symlinking ${source} to ${destination}"
		symlink "${source}" "${destination}"
	fi
	
	# ninja
	source="${app_directory}/ninja"
	
	if [ -f "${source}" ] && [ -d "${cmake_directory}" ]; then
		for subdirectory in "${cmake_directory}/"*; do
			destination="${subdirectory}/bin/ninja"
			
			[ -d "${subdirectory}/bin" ] || mkdir "${subdirectory}/bin"
			
			if [[ "$(readlink "${destination}")" != "${source}" ]]; then
				echo "symlinking ${source} to ${destination}"
				symlink "${source}" "${destination}"
			fi
		done
	fi
	
	for triplet in "${triplets[@]}"; do
		declare original_triplet="${triplet}"
		
		if [ "${triplet}" = 'arm-linux-androideabi' ]; then
			triplet='armv7a-linux-androideabi'
		fi
		
		declare canonical_triplet="${triplet/-linux/-unknown-linux}"
		canonical_triplet="${canonical_triplet/armv7a/armv7}"
		
		for name in "${binutils[@]}"; do
			declare source="${app_directory}/${canonical_triplet}-${name}"
			declare destination="${directory}/toolchains/llvm/prebuilt/${slug}/bin/${triplet}-${name}"
			
			if ! [ -f "${source}" ]; then
				continue
			fi
			
			if [[ "$(readlink "${destination}")" != "${source}" ]]; then
				echo "symlinking ${source} to ${destination}"
				symlink "${source}" "${destination}"
			fi
			
			declare subdirectory=''
			
			if [ "${original_triplet}" = 'x86_64-linux-android' ]; then
				subdirectory="${toolchains_directory}/x86_64-4.9"
			elif [ "${original_triplet}" = 'i686-linux-android' ]; then
				subdirectory="${toolchains_directory}/x86-4.9"
			else
				subdirectory="${toolchains_directory}/${original_triplet}-4.9"
			fi
			
			if [ -d "${subdirectory}" ]; then
				subdirectory+="/prebuilt/${slug}/bin"
				destination="${subdirectory}/${original_triplet}-${name}"
				
				if [[ "$(readlink "${destination}")" != "${source}" ]]; then
					echo "symlinking ${source} to ${destination}"
					symlink "${source}" "${destination}"
				fi
				
				subdirectory="${subdirectory/\/bin/}"
				subdirectory+="/${original_triplet}/bin"
				
				destination="${subdirectory}/${name}"
				
				if [[ "$(readlink "${destination}")" != "${source}" ]]; then
					echo "symlinking ${source} to ${destination}"
					symlink "${source}" "${destination}"
				fi
			fi
			
			if [ "${original_triplet}" = "${triplet}" ]; then
				continue
			fi
			
			destination="${directory}/toolchains/llvm/prebuilt/${slug}/bin/${original_triplet}-${name}"
			
			if [[ "$(readlink "${destination}")" != "${source}" ]]; then
				echo "symlinking ${source} to ${destination}"
				symlink "${source}" "${destination}"
			fi
		done
		
		for version in "${versions[@]}"; do
			declare source="${app_directory}/${canonical_triplet}${version}-clang"
			declare destination="${directory}/toolchains/llvm/prebuilt/${slug}/bin/${triplet}${version}-clang"
			
			if ! [ -f "${source}" ]; then
				continue
			fi
			
			if [[ "$(readlink "${destination}")" != "${source}" ]]; then
				echo "symlinking ${source} to ${destination}"
				symlink "${source}" "${destination}"
			fi
			
			source+='++'
			destination+='++'
			
			if [[ "$(readlink "${destination}")" != "${source}" ]]; then
				echo "symlinking ${source} to ${destination}"
				symlink "${source}" "${destination}"
			fi
		done
	done
done

if [ "${symlinks}" -eq 0 ]; then
	echo 'nothing to do!' >&2
else
	echo "${symlinks} files were modified"
fi

exit '0'
