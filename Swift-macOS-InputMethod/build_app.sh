#!/bin/bash
# Build ioDiacritics Sisana.app -- a macOS Input Method Kit demo.
set -euo pipefail

cd "$(dirname "$0")"

BUILD_PATH="/tmp/ioDiacriticsInputMethod-build"
CONFIG="release"
APP="dist/ioDiacritics Šišana.app"
BUNDLE_ID="com.ilyaosipov.iodiacritics.inputmethod"
CONNECTION="IODiacriticsInputMethodConnection"
VERSION="0.1.0"

echo "==> swift build (${CONFIG})..."
swift build -c "${CONFIG}" --build-path "${BUILD_PATH}"

PRODUCTS="$(swift build -c "${CONFIG}" --build-path "${BUILD_PATH}" --show-bin-path)"
BIN="${PRODUCTS}/DiacriticsInputMethod"

echo "==> assembling ${APP} ..."
rm -rf "${APP}"
mkdir -p "${APP}/Contents/MacOS" "${APP}/Contents/Resources"
cp "${BIN}" "${APP}/Contents/MacOS/DiacriticsInputMethod"

copied_bundles=0
for b in "${PRODUCTS}"/ioDiacritics_*.bundle; do
    if [ -d "${b}" ]; then
        cp -R "${b}" "${APP}/Contents/Resources/"
        copied_bundles=$((copied_bundles + 1))
    fi
done
if [ "${copied_bundles}" -eq 0 ]; then
    echo "ERROR: no ioDiacritics resource bundles found in ${PRODUCTS}" >&2
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
    <key>CFBundleName</key>                 <string>ioDiacritics Šišana</string>
    <key>CFBundleDisplayName</key>          <string>ioDiacritics Šišana</string>
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
            <string>ioDiacritics Šišana</string>
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
