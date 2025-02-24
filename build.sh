#!/bin/bash

# set -eu

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
		cp --recursive "./Build/${target}/Root/usr" "${triplet}"
		rm --force --recursive "${triplet}/src" "${triplet}/Tests"
	fi
	
	while read name; do
		"./Toolchain/Local/${target}/bin/${target}-pc-serenity-strip" --strip-all "${name}" || true
	done <<< "$(find "${triplet}/lib" -name '*.so')"
	
	cp --recursive "${PWD}/Userland/Libraries/LibC" "${triplet}/include/Userland/Libraries"
	cp --recursive "${PWD}/Userland/Libraries/LibELF" "${triplet}/include/Userland/Libraries"
	cp --recursive "${PWD}/Userland/Libraries/LibRegex" "${triplet}/include/Userland/Libraries"
	
	pushd "${triplet}/include"
	
	while read destination; do
		declare path="$(stat --printf='%N\n' "${destination}" | sed --regexp-extended "s|.+LibC/||g; s/'//g")"
		declare directory="$(dirname "${path}")"
		declare source="Userland/Libraries/LibC/${path}"
		
		IFS='/' read -ra components <<< "${directory}"
		declare components="${#components[@]}"
		
		if [ "${directory}" = '.' ]; then
			(( components -= components ))
		fi
		
		if (( components > 0 )); then
			while [ "${components}" != '0' ]; do
				(( components -= 1 ))
				source="../${source}"
			done
		else
			source="./${source}"
		fi
		
		echo "- Unlinking '${destination}'"
		unlink "${destination}"
		
		echo "- Symlinking '${source}' to '${destination}'"
		ln --symbolic "${source}" "${destination}"
	done <<< "$(find './' -type 'l' -wholename '*.h')"
	
	declare name='LibRegex/RegexDefs.h'
	unlink "${name}"
	
	ln --symbolic "../Userland/Libraries/LibC/../${name}" "./${name}" 
	
	declare name='LibELF/ELFABI.h'
	unlink "${name}"
	
	ln --symbolic "../Userland/Libraries/LibC/../${name}" "./${name}" 
	
	while read name; do
		echo "- Unlinking '${name}'"
		unlink "${name}"
	done <<< "$(find './' '(' -wholename '*.txt' -o -wholename '*.cpp' ')')"
	
	pushd
	
	tar --create --file=- "${triplet}" |  xz --threads=0 --compress -9 > "${tarball_filename}"
	sha256sum "${tarball_filename}" > "${tarball_filename}.sha256"
done

exit '0'
