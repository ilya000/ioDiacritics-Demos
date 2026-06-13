#!/bin/bash
# Build ioDiacriticsDemo.app -- a small windowed showcase for the sibling ioDiacritics library.
# ASCII-only on purpose: macOS ships bash 3.2, which under a C/POSIX locale can absorb
# adjacent multibyte chars into a preceding ${var}, tripping `set -u`.
set -euo pipefail

cd "$(dirname "$0")"
BUILD_PATH="/tmp/ioDiacriticsDemo-build"
CONFIG="release"
APP="dist/ioDiacriticsDemo.app"
BUNDLE_ID="com.ilyaosipov.iodiacriticsdemo"
VERSION="0.1.0"
BUILD="$(( $(cat .build_number 2>/dev/null || echo 0) + 1 ))"
echo "${BUILD}" > .build_number

echo "==> swift build (${CONFIG})... v${VERSION} (${BUILD})"
swift build -c "${CONFIG}" --build-path "${BUILD_PATH}"

BIN="${BUILD_PATH}/${CONFIG}/DiacriticsDemo"
PRODUCTS="${BUILD_PATH}/${CONFIG}"

echo "==> assembling ${APP} ..."
rm -rf "${APP}"
mkdir -p "${APP}/Contents/MacOS" "${APP}/Contents/Resources"
cp "${BIN}" "${APP}/Contents/MacOS/ioDiacriticsDemo"

# The diacritics dictionaries live in the shared ioDiacritics package; its per-language data
# targets bundle deshishana_*.json via Bundle.module, so copy those resource bundles in.
for b in "${PRODUCTS}"/ioDiacritics_*.bundle; do
    [ -d "${b}" ] && cp -R "${b}" "${APP}/Contents/Resources/"
done

cat > "${APP}/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>            <string>ioDiacriticsDemo</string>
    <key>CFBundleDisplayName</key>     <string>ioDiacritics Demo</string>
    <key>CFBundleIdentifier</key>      <string>${BUNDLE_ID}</string>
    <key>CFBundleExecutable</key>      <string>ioDiacriticsDemo</string>
    <key>CFBundlePackageType</key>     <string>APPL</string>
    <key>CFBundleShortVersionString</key> <string>${VERSION}</string>
    <key>CFBundleVersion</key>         <string>${BUILD}</string>
    <key>LSMinimumSystemVersion</key>  <string>13.0</string>
    <key>NSPrincipalClass</key>        <string>NSApplication</string>
    <key>NSHighResolutionCapable</key> <true/>
</dict>
</plist>
PLIST

echo "==> codesign ad-hoc"
codesign --force --deep --sign - "${APP}" 2>/dev/null || codesign --force --sign - "${APP}"

echo "OK: built ${APP}"
echo "    open with:  open \"${PWD}/${APP}\""
