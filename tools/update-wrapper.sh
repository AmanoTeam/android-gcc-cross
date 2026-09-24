#!/usr/bin/env bash

declare -r APP_DIRECTORY="$(realpath "$(( [ -n "${BASH_SOURCE}" ] && dirname "$(realpath "${BASH_SOURCE[0]}")" ) || dirname "$(realpath "${0}")")")"

cd "$(mktemp --directory)"
trap 'rm --force --recursive "${PWD}"' EXIT

git clone --depth '1' 'https://github.com/AmanoTeam/obggcc'

make -C "${PWD}/obggcc/tools/gcc-wrapper" all FLAVOR=PINO PREFIX="${PWD}"

for path in "${APP_DIRECTORY}/"*{clang,gcc}; do
	if [[ "${path}" = *'android-gcc' || "${path}" = *'androideabi-gcc' ]]; then
		continue
	fi
	
	if [[ "${path}" = *'android-g++' || "${path}" = *'androideabi-g++' ]]; then
		continue
	fi
	
	cp "${PWD}/gcc-wrapper" "${path}"
done

for path in "${APP_DIRECTORY}/"*{clang,g}'++'; do
	if [[ "${path}" = *'android-gcc' || "${path}" = *'androideabi-gcc' ]]; then
		continue
	fi
	
	if [[ "${path}" = *'android-g++' || "${path}" = *'androideabi-g++' ]]; then
		continue
	fi
	
	cp "${PWD}/gcc-wrapper" "${path}"
done
