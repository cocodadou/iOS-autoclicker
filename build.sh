#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${THEOS:-}" ]]; then
  echo "THEOS is not set. Install Theos and export THEOS before building." >&2
  exit 1
fi

git submodule update --init --recursive
make clean
make package FINALPACKAGE=1

mkdir -p dist
DYLIB_PATH="$(find .theos -type f -name 'AdvancedAutoClicker.dylib' -print -quit)"
DEB_PATH="$(find packages -type f -name '*.deb' -print | sort | tail -n 1)"

if [[ -z "$DYLIB_PATH" || -z "$DEB_PATH" ]]; then
  echo "Build finished but one or more expected outputs are missing." >&2
  exit 1
fi

cp "$DYLIB_PATH" dist/AdvancedAutoClicker.dylib
cp "$DEB_PATH" dist/AdvancedAutoClicker.deb
shasum -a 256 dist/AdvancedAutoClicker.dylib dist/AdvancedAutoClicker.deb > dist/SHA256SUMS.txt

echo "Outputs are available in ./dist"
