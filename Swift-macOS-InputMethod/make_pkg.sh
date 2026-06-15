#!/usr/bin/env bash
# Build a signed + notarized .pkg installer for the Šišana input method.
#
# The installer drops Šišana.app into /Library/Input Methods (system-wide; macOS asks the user
# to authenticate as admin during install). That is the correct location for an IME — it does
# NOT go to /Applications, so a "drag to Applications" DMG is the wrong vehicle.
#
# Requirements (one-time):
#   • A personal "Developer ID Application" cert  (signs the .app)            — already set up.
#   • A personal "Developer ID Installer"  cert   (signs the .pkg)            — CREATE THIS:
#       Xcode ▸ Settings ▸ Accounts ▸ Manage Certificates ▸ + ▸ "Developer ID Installer".
#   • notarytool keychain profile "iodia-notary"  (Apple ID + app-specific pw + team id).
#
# Then:  ./make_pkg.sh   →   dist/Šišana.pkg  (signed, notarized, stapled)
#
# Overrides: IODIA_SIGN_ID=<hash> (app), IODIA_INSTALLER_ID=<hash> (pkg),
#            IODIA_NOTARY_PROFILE=<name>, IODIA_SKIP_NOTARIZE=1.
set -euo pipefail
cd "$(dirname "$0")"

APP="dist/Šišana.app"
PKG="dist/Šišana.pkg"
COMPONENT="dist/Šišana-component.pkg"
PKG_ID="com.ilyaosipov.sisana.installer"
VERSION="0.1.0"
NOTARY_PROFILE="${IODIA_NOTARY_PROFILE:-iodia-notary}"

# 1. Build the .app
./build_app.sh

# 2. Sign the .app with Developer ID Application + hardened runtime (required to notarize).
APP_ID="${IODIA_SIGN_ID:-}"
if [ -z "${APP_ID}" ]; then
    APP_ID="$(security find-identity -v -p codesigning | awk '/Developer ID Application/ && !/Cubios/ {print $2; exit}')"
fi
if [ -z "${APP_ID}" ]; then
    echo "!! No personal 'Developer ID Application' identity (Cubios is intentionally excluded)." >&2
    exit 1
fi
echo "==> signing app with: ${APP_ID}"
codesign --force --deep --options runtime --timestamp --sign "${APP_ID}" "${APP}"
codesign --verify --deep --strict --verbose=2 "${APP}"

# 3. Build a component pkg whose payload installs into /Library/Input Methods.
echo "==> pkgbuild ..."
rm -f "${PKG}" "${COMPONENT}"
pkgbuild --install-location "/Library/Input Methods" \
         --identifier "${PKG_ID}" --version "${VERSION}" \
         --component "${APP}" "${COMPONENT}"

# 4. Sign the pkg with Developer ID Installer.
INST_ID="${IODIA_INSTALLER_ID:-}"
if [ -z "${INST_ID}" ]; then
    INST_ID="$(security find-identity -v | awk '/Developer ID Installer/ && !/Cubios/ {print $2; exit}')"
fi
if [ -z "${INST_ID}" ]; then
    echo "!! No 'Developer ID Installer' identity — create one in your Apple Developer account." >&2
    echo "   Unsigned component pkg left at ${COMPONENT} (LOCAL TESTING ONLY, not for distribution)." >&2
    exit 1
fi
echo "==> productsign with: ${INST_ID}"
productsign --sign "${INST_ID}" "${COMPONENT}" "${PKG}"
rm -f "${COMPONENT}"

# 5. Notarize + staple the pkg.
if [ "${IODIA_SKIP_NOTARIZE:-0}" = "1" ]; then
    echo "==> IODIA_SKIP_NOTARIZE=1 — signed pkg built, notarization skipped."
elif xcrun notarytool history --keychain-profile "${NOTARY_PROFILE}" >/dev/null 2>&1; then
    echo "==> notarizing (profile: ${NOTARY_PROFILE}) — a few minutes..."
    xcrun notarytool submit "${PKG}" --keychain-profile "${NOTARY_PROFILE}" --wait
    xcrun stapler staple "${PKG}"
    xcrun stapler validate "${PKG}"
else
    echo "!! notarytool profile '${NOTARY_PROFILE}' not set up — pkg is signed but NOT notarized." >&2
fi

echo "OK: ${PKG}"
