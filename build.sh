#!/bin/bash

set -eu

sudo apt-get install --assume-yes 'libmpc-dev' 'ninja-build'

declare -r MAKEJOBS='40'

declare -ra targets=(
	'riscv64'
	'x86_64'
	'aarch64'
)

declare -r revision='e10d5a4'

export MAKEJOBS

[ -d './serenity' ] || git clone 'https://github.com/SerenityOS/serenity.git'

cd './serenity'

git checkout "${revision}"

for target in "${targets[@]}"; do
	declare triplet="${target}-unknown-serenity"
	declare tarball_filename="${triplet}.tar.xz"
	
	if ! ( [ -d "./Build/${target}/Root/usr" ] || [ -d "${triplet}" ] ); then
		/proc/self/exe './Meta/serenity.sh' build "${target}"
	fi
	
	if ! [ -d "${triplet}" ]; then
		mv "./Build/${target}/Root/usr" "${triplet}"
		rm --force --recursive "${triplet}/src" "${triplet}/Tests"
	fi
	
	while read name; do
		"./Toolchain/Local/${target}/bin/${target}-pc-serenity-strip" --strip-all "${name}" || true
	done <<< "$(find "${triplet}/lib" -name '*.so')"
	
	tar --create --file=- "${triplet}" |  xz --threads=0 --compress -9 > "${tarball_filename}"
	sha256sum "${tarball_filename}" > "${tarball_filename}.sha256"
done

exit '0'
