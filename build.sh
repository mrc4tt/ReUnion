#!/bin/bash

main()
{
	CC=gcc
	CXX=g++

	if [[ "$*" =~ "--help" ]]; then
		help
		exit 0;
	fi

	n=0
	args=()
	for i in "$@"
	do
	case $i in
		-j=*|--jobs=*)
			jobs="-j${i#*=}"
			shift
		;;
		-c=*|--compiler=*)
			C="${i#*=}"
			shift
		;;
		*)
		args[$n]="$i"
		((++n))
		;;
	esac
	done

	case "$C" in
		("intel"|"icc")		CC=icc CXX=icpc ;;
		("gcc"|"g++")		CC=gcc CXX=g++ ;;
		("clang"|"llvm")	CC=clang CXX=clang++ ;;
		*)
		;;
	esac

	rm -rf build
	mkdir build
	pushd build &> /dev/null
	CC=$CC CXX=$CXX cmake ${args[@]} ..
	make ${jobs}
	build_rc=$?
	popd > /dev/null

	if [[ $build_rc -ne 0 ]]; then
		echo "Build failed (rc=$build_rc), skipping packaging."
		exit $build_rc
	fi

	package
}

# Replicates the Linux "Move files" step from .github/workflows/build.yml,
# producing a publish/ tree laid out the way a release archive expects.
package()
{
	local so="build/reunion/reunion_mm_i386.so"

	if [[ ! -f "$so" ]]; then
		echo "Error: $so not found, cannot package."
		exit 1
	fi

	rm -rf publish
	mkdir -p publish/addons/reunion publish/addons/amxmodx/scripting publish/src
	rsync -a reunion/dist/ publish/ --exclude=*.tpl
	rsync -a reunion/src/reunion_api.h publish/src/
	rsync -a reunion/extra/ publish/addons/amxmodx/scripting/
	cp "$so" publish/addons/reunion/reunion_mm_i386.so

	echo "Packaged release files into publish/"
}

help()
{
	printf "Usage: ./build.sh <options>\n\n"
	printf "  -c= | --compiler=<icc|gcc|clang> - Select preferred C/C++ compiler to build\n"
	printf "  -j= | --jobs=<N>                 - Specifies the number of jobs (commands) to run simultaneously (For faster building)\n\n"
}

# Initialize
main $*

# Exit normally
exit 0
