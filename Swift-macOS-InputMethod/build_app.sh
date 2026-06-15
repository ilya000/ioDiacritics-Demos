#!/bin/bash
# Build Šišana.app -- a macOS Input Method (IME) for ioDiacritics (Bosnian/Croatian/Serbian
# diacritic restoration with a candidate window). Installs as a system input source.
set -euo pipefail

cd "$(dirname "$0")"

BUILD_PATH="/tmp/ioDiacriticsInputMethod-build"
CONFIG="release"
APP="dist/Šišana.app"
BUNDLE_ID="com.ilyaosipov.sisana"
CONNECTION="SisanaInputMethodConnection"
VERSION="0.1.0"

echo "==> swift build (${CONFIG})..."
swift build -c "${CONFIG}" --build-path "${BUILD_PATH}"

PRODUCTS="$(swift build -c "${CONFIG}" --build-path "${BUILD_PATH}" --show-bin-path)"
BIN="${PRODUCTS}/DiacriticsInputMethod"

echo "==> assembling ${APP} ..."
rm -rf "${APP}"
mkdir -p "${APP}/Contents/MacOS" "${APP}/Contents/Resources"
cp "${BIN}" "${APP}/Contents/MacOS/DiacriticsInputMethod"

# Copy the bare deshishana_*.json into Contents/Resources. The controller loads them via
# Bundle.main (NOT Bundle.module): the SwiftPM resource bundles ship without an Info.plist and
# Bundle.module can fatalError under LaunchServices, so we avoid it.
copied_dicts=0
for b in "${PRODUCTS}"/ioDiacritics_*.bundle; do
    if [ -d "${b}" ]; then
        for j in "${b}"/*.json; do
            [ -f "${j}" ] && cp "${j}" "${APP}/Contents/Resources/" && copied_dicts=$((copied_dicts + 1))
        done
    fi
done
if [ "${copied_dicts}" -eq 0 ]; then
    echo "ERROR: no deshishana_*.json dictionaries found in ${PRODUCTS}" >&2
    exit 1
fi

if [ -f ../Swift-macOS/AppIcon.icns ]; then
    cp ../Swift-macOS/AppIcon.icns "${APP}/Contents/Resources/AppIcon.icns"
fi

cat > "${APP}/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>                 <string>Šišana</string>
    <key>CFBundleDisplayName</key>          <string>Šišana</string>
    <key>CFBundleIdentifier</key>           <string>${BUNDLE_ID}</string>
    <key>CFBundleExecutable</key>           <string>DiacriticsInputMethod</string>
    <key>CFBundleIconFile</key>             <string>AppIcon</string>
    <key>CFBundlePackageType</key>          <string>APPL</string>
    <key>CFBundleShortVersionString</key>   <string>${VERSION}</string>
    <key>CFBundleVersion</key>              <string>1</string>
    <key>LSMinimumSystemVersion</key>       <string>13.0</string>
    <key>LSUIElement</key>                  <true/>
    <key>NSHighResolutionCapable</key>      <true/>
    <key>NSPrincipalClass</key>             <string>NSApplication</string>

    <key>InputMethodConnectionName</key>    <string>${CONNECTION}</string>
    <key>InputMethodServerControllerClass</key>
    <string>IODiacriticsInputController</string>
    <key>InputMethodServerDelegateClass</key>
    <string>IODiacriticsAppDelegate</string>
    <key>tsInputMethodCharacterRepertoireKey</key>
    <array>
        <string>Latn</string>
    </array>
    <key>tsInputMethodIconFileKey</key>     <string>AppIcon.icns</string>
    <key>ComponentInputModeDict</key>
    <dict>
        <key>${BUNDLE_ID}.bcs</key>
        <dict>
            <key>tsInputModeLocalizedNameKey</key>
            <string>Šišana</string>
            <key>tsInputModeScriptKey</key>
            <string>Latn</string>
        </dict>
    </dict>
</dict>
</plist>
PLIST

echo "==> codesign ad-hoc"
codesign --force --deep --sign - "${APP}" 2>/dev/null || codesign --force --sign - "${APP}"

echo "OK: built ${APP}"
