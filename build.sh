#!/bin/sh
set -eu
cd "$(dirname "$0")"
: "${THEOS:?Set THEOS to the RootHide Theos checkout described in BUILD.md}"
export CLANG_MODULE_CACHE_PATH="$PWD/.build-cache/modules"
variant=${1:-all}
case "$variant" in
    all) variants="roothide rootless" ;;
    roothide|rootless) variants=$variant ;;
    *) echo 'Usage: sh build.sh [roothide|rootless|all]' >&2; exit 2 ;;
esac
sh tests/run.sh
mkdir -p validation
for scheme in $variants; do
    make clean package THEOS_PACKAGE_SCHEME="$scheme"
    if [ "$scheme" = roothide ]; then arch=iphoneos-arm64e; else arch=iphoneos-arm64; fi
    package="packages/com.sahinkaa.velvetliquidglass_1.0.0_${arch}.deb"
    python3 normalize_ownership.py "$package"
    python3 validate_package.py "$package" "$scheme" > "validation/$scheme.json"
done
