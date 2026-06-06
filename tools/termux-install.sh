#!/data/data/com.termux/files/usr/bin/bash

set -eu

declare -r abi="$(/system/bin/uname -m)"
declare secondary_abi=""

declare multilib='-m32'

declare api_level='-1'

declare max_api_level='36'

declare triplet='none'
declare bindir="${PREFIX}/bin/gcc-toolchain"

declare pino_tarball="${TMPDIR}/gcc-toolchain.tar.xz"
declare pino_directory='/data/data/com.termux/files/usr/lib/android-gcc-cross'

declare patchelf='patchelf'

declare wrapper="$(
cat << text
#!/data/data/com.termux/files/usr/bin/bash

export PINO_RUNTIME_RPATH='true'
export PINO_NEON='true'

export PINO_SYSTEM_PREFIX=\"\$(dirname \"\${PREFIX}\")\"
export PINO_SYSTEM_LIBRARIES='true'

export LD_LIBRARY_PATH=\"%s:\${LD_LIBRARY_PATH}\"

declare -r secondary_target='%s'
declare -r multilib='%s'

if [[ \" \${@} \" = *\" \${multilib} \"* ]]; then
	unset PINO_SYSTEM_PREFIX
	unset PINO_SYSTEM_LIBRARIES
	
	declare -a args=()
	
	for arg in \"\${@}\"; do
		if [ \"\${arg}\" = \"\${multilib}\" ]; then
			continue
		fi
		
		args+=(\"\${arg}\")
	done
	
	exec '%s' \"\${args[@]}\"
else
	exec '%s' -march=native \"\${@}\"
fi

text
)"

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

declare -ra rc_files=(
	"${HOME}/.zshrc"
	"${HOME}/.bashrc"
	"${HOME}/.config/fish/config.fish"
)

function get_secondary_abi() {
	
	local secondary_abi=''
	
	case "${1}" in
		aarch64)
			secondary_abi='armv7l'
			;;
		x86_64)
			secondary_abi='i686'
			;;
		mips64)
			secondary_abi='mips'
			;;
		armv7l)
			secondary_abi='aarch64'
			;;
		i686)
			secondary_abi='x86_64'
			;;
		mips)
			secondary_abi='mips64'
			;;
	esac
	
	echo "${secondary_abi}"
	
}


function get_triplet() {
	
	local triplet=''
	
	case "${1}" in
		aarch64)
			triplet='aarch64-unknown-linux-android'
			;;
		armv7l)
			triplet='armv7-unknown-linux-androideabi'
			;;
		i686)
			triplet='i686-unknown-linux-android'
			;;
		x86_64)
			triplet='x86_64-unknown-linux-android'
			;;
		mips64)
			triplet='mips64el-unknown-linux-android'
			;;
		mips)
			triplet='mipsel-unknown-linux-android'
			;;
		riscv64)
			triplet='riscv64-unknown-linux-android'
			;;
	esac
	
	echo "${triplet}"
	
}

[ -f '/system/bin/getprop' ] && api_level="$(getprop 'ro.build.version.sdk')"

if [ "${api_level}" = '-1' ]; then
	# We are probably running inside termux-docker; assume API level 24
	api_level='24'
fi

triplet="$(get_triplet "${abi}")"

declare -r secondary_abi="$(get_secondary_abi "${abi}")"
declare -r secondary_triplet="$(get_triplet "${secondary_abi}")"

if [ -z "${triplet}" ]; then
	echo "fatal error: unknown ABI: ${abi}" 1>&2
	exit '1'
fi

if [[ "${triplet}" = 'mips'*'-unknown-linux-android' ]]; then
	max_api_level='27'
fi

if [ "${api_level}" -gt "${max_api_level}" ]; then
	api_level="${max_api_level}"
fi

if [[ "${secondary_abi}" = *'64' ]]; then
	multilib="${multilib/32/64}"
fi

declare url="https://github.com/AmanoTeam/android-gcc-cross/releases/download/gcc-16/${triplet}.tar.xz"

echo "- Fetching archive from '${url}' to '${pino_tarball}'"

curl \
	--url "${url}" \
	--retry '5' \
	--retry-all-errors \
	--retry-delay '0' \
	--retry-max-time '0' \
	--location \
	--output "${pino_tarball}"

if [ -d "${pino_directory}" ]; then
	echo "- Removing '${pino_directory}'"
	rm --force --recursive "${pino_directory}"
fi

if [ -d "${bindir}" ]; then
	echo "- Removing '${bindir}'"
	rm --force --recursive "${bindir}"
fi

mkdir --parent "${bindir}"

echo "- Unpacking tarball from '${pino_tarball}' to '${pino_directory}'"

tar \
	--directory="$(dirname "${pino_directory}")" \
	--extract \
	--file="${pino_tarball}"

echo "- Symlinking host tools to '${bindir}'"

for name in "${pino_directory}/bin/"*'-unknown-'*; do
	ln \
		--symbolic \
		--force \
		"${name}" \
		"${bindir}"
done

for name in "${binutils[@]}"; do
	ln \
		--symbolic \
		--force \
		"${pino_directory}/bin/${triplet}-${name}" \
		"${bindir}/${name}"
done

rm --force "${bindir}/gcc"

printf \
	"${wrapper}" \
	"${pino_directory}/lib" \
	"${secondary_triplet}" \
	"${multilib}" \
	"${pino_directory}/bin/${secondary_triplet}${api_level}-gcc" \
	"${pino_directory}/bin/${triplet}${api_level}-gcc" > "${bindir}/gcc"

chmod 700 "${bindir}/gcc"

rm --force "${bindir}/cc"
cp "${bindir}/gcc" "${bindir}/cc"

rm --force "${bindir}/g++"

sed "s/${api_level}-gcc/${api_level}-g++/g" "${bindir}/gcc" > "${bindir}/g++"

chmod 700 "${bindir}/g++"

rm --force "${bindir}/c++"
cp "${bindir}/g++" "${bindir}/c++"

echo "- Removing '${pino_tarball}'"

unlink "${pino_tarball}"

declare expression="export PATH=\"${bindir}:\$PATH\""

touch "${HOME}/.bashrc"

for rc_file in "${rc_files[@]}"; do
	if [ -f "${rc_file}" ] && [[ "$(cat "${rc_file}")" != *"${expression}"* ]]; then
		echo "- Modifying '${rc_file}'"
		echo -e "${expression}" >> "${rc_file}"
	fi
done

if ! command -v "${patchelf}" >/dev/null 2>&1; then
	patchelf="${pino_directory}/bin/patchelf"
fi

echo "- Adding custom DT_RUNPATH to GCC runtime libraries"

for library in "${pino_directory}/${triplet}${api_level}/lib/gcc/lib"*'.so'; do
	"${patchelf}" --set-rpath "${pino_directory}/${triplet}${api_level}/lib/gcc" "${library}" 2>/dev/null || true
done

if [ -n "${secondary_triplet}" ]; then
	for library in "${pino_directory}/${secondary_triplet}${api_level}/lib/gcc/lib"*'.so'; do
		"${patchelf}" --set-rpath "${pino_directory}/${secondary_triplet}${api_level}/lib/gcc" "${library}" 2>/dev/null || true
	done
fi

echo '- Installation finished!'
