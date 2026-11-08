#!/bin/bash
# Runs INSIDE docker/Dockerfile. Mirrors the linux job of build.yml:
# release build, dist/api/amxx scripting + reunion_mm_i386.so into publish/, glibc check.
set -euo pipefail
git config --global --add safe.directory '*'

echo "==> Release build"
rm -rf build
CC=gcc CXX=g++ cmake -B build
cmake --build build -j"$(nproc)"

echo "==> publish/ (linux)"
rm -rf publish/linux
mkdir -p publish/linux/addons/reunion publish/linux/addons/amxmodx/scripting publish/linux/src
rsync -a reunion/dist/ publish/linux/ --exclude='*.tpl'
rsync -a reunion/src/reunion_api.h publish/linux/src/
rsync -a reunion/extra/ publish/linux/addons/amxmodx/scripting/
cp build/reunion/reunion_mm_i386.so publish/linux/addons/reunion/reunion_mm_i386.so
cp reunion/version/appversion.h publish/appversion.h

echo "==> GLIBC/ABI compat test"
bash ./reunion/version/glibc_test.sh publish/linux/addons/reunion/reunion_mm_i386.so
