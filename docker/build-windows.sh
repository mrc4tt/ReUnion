#!/bin/bash
# Windows build, mirroring the windows job of build.yml with support/vcxbuild.py
# (cl/link from msvc-wine) in place of msbuild. Two steps, two images:
#
#   build-windows.sh compile   in Dockerfile.windows (msvc-wine): Release
#   build-windows.sh finish    in Dockerfile.wine32 (Authenticode when /run/sign/cert.pfx is mounted): publish/, rcedit (needs COMMIT in the environment)
set -euo pipefail
owner=$(stat -c %u:%g .)

case "${1:-}" in
compile)
	git config --global --add safe.directory '*'
	reunion/version/appversion.sh . >/dev/null
	rm -rf build-win
	echo "==> Release"
	python3 support/vcxbuild.py reunion/msvc/Reunion.vcxproj --sln msvc/Reunion.sln --config Release --out build-win
	chown -R "$owner" build-win reunion/version/appversion.h
	;;
finish)
	APP_VERSION=$(sed -n 's/^#define APP_VERSION_STRD[[:space:]]*"\([^"]*\)".*/\1/p' reunion/version/appversion.h)
	echo "==> publish/ (win32)"
	rm -rf publish/win32
	mkdir -p publish/win32/addons/reunion
	cp build-win/Release/reunion_mm.dll publish/win32/addons/reunion/reunion_mm.dll

	echo "==> rcedit $APP_VERSION"
	wine /opt/rcedit-x86.exe publish/win32/addons/reunion/reunion_mm.dll \
		--set-version-string ProductName "ReUnion - reunion_mm.dll" \
		--set-file-version "$APP_VERSION" --set-product-version "$APP_VERSION" \
		--set-version-string FileDescription "Reunion - is a continuation of the DProto project adapted for ReHLDS., Commit: $COMMIT" \
		--set-version-string Comments "Metamod plugin that allows protocol 47 and 48 non-steam clients to connect to ReHLDS servers, Commit: $COMMIT" \
		--set-version-string CompanyName "ReHLDS Dev Team" \
		--set-version-string LegalCopyright "Copyright 2025 Valve, ReHLDS DevTeam" \
		--set-icon reunion/msvc/icon.ico
	if [ -f /run/sign/cert.pfx ]; then
		echo "==> Authenticode signing"
		f=publish/win32/addons/reunion/reunion_mm.dll
		osslsigncode sign -pkcs12 /run/sign/cert.pfx -readpass /run/sign/pass -h sha256 \
			-n "ReUnion - reunion_mm.dll" -i "https://github.com/$SLUG" -ts "$PFX_TIMESTAMP" -in "$f" -out "$f.signed"
		mv "$f.signed" "$f"
	fi
	chown -R "$owner" build-win publish
	;;
*) echo "usage: build-windows.sh compile|finish" >&2; exit 2 ;;
esac
