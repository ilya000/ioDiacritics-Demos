#!/usr/bin/env bash
# Build a signed + notarized DISTRIBUTION .pkg installer for the Šišana input method.
#
# Domain-relocatable: the macOS Installer offers
#   • "Install for all users of this computer" → /Library/Input Methods  (needs admin/root)
#   • "Install for me only"                    → ~/Library/Input Methods (no admin)
# i.e. if the user can authenticate as admin they can install it system-wide; otherwise it
# installs just for them. A postinstall step refreshes the input-source menu so Šišana appears
# without a logout. The payload app is Developer-ID signed + hardened-runtime, the pkg is signed
# with a Developer ID Installer cert, then notarized + stapled.
#
# Requirements: Developer ID Application cert (app), Developer ID Installer cert (pkg),
#               notarytool keychain profile "iodia-notary".
# Overrides: IODIA_SIGN_ID, IODIA_INSTALLER_ID, IODIA_NOTARY_PROFILE, IODIA_SKIP_NOTARIZE=1.
set -euo pipefail
cd "$(dirname "$0")"

APP="dist/Šišana.app"
PKG="dist/Sisana-InputMethod.pkg"
PKG_ID="com.ilyaosipov.sisana"
VERSION="0.1.0"
NOTARY_PROFILE="${IODIA_NOTARY_PROFILE:-iodia-notary}"
# Build artifacts under dist/ (gitignored). pkgbuild/productbuild create their temp dirs next to
# the output, and writing those under /tmp is blocked in some sandboxed contexts, so keep them here.
STAGE="dist/_pkgroot"
SCRIPTS="dist/_pkgscripts"
COMPONENT="dist/_sisana-component.pkg"
DIST="dist/_sisana-distribution.xml"
UNSIGNED="dist/_sisana-unsigned.pkg"

# 1. Build + Developer ID-sign the app (hardened runtime + secure timestamp).
./build_app.sh
APP_ID="${IODIA_SIGN_ID:-}"
[ -z "${APP_ID}" ] && APP_ID="$(security find-identity -v -p codesigning | awk '/Developer ID Application/ && !/Cubios/ {print $2; exit}')"
[ -z "${APP_ID}" ] && { echo "!! no personal Developer ID Application identity" >&2; exit 1; }
echo "==> signing app: ${APP_ID}"
codesign --force --options runtime --timestamp --sign "${APP_ID}" "${APP}"
codesign --verify --strict "${APP}"

# 2. Stage payload so the app lands at <domain>/Library/Input Methods/Šišana.app.
rm -rf "${STAGE}" "${SCRIPTS}"; mkdir -p "${STAGE}" "${SCRIPTS}"
cp -R "${APP}" "${STAGE}/"

# postinstall: refresh the input-source menu (so Šišana shows up without a logout).
cat > "${SCRIPTS}/postinstall" <<'SH'
#!/bin/bash
/usr/bin/killall TextInputMenuAgent 2>/dev/null || true
exit 0
SH
chmod +x "${SCRIPTS}/postinstall"

# 3. Component pkg — RELATIVE install-location ⇒ domain-relocatable.
rm -f "${COMPONENT}"
pkgbuild --root "${STAGE}" \
         --install-location "Library/Input Methods" \
         --scripts "${SCRIPTS}" \
         --identifier "${PKG_ID}" --version "${VERSION}" \
         "${COMPONENT}"

# 4. Distribution XML — enable BOTH the per-user and the system domain.
cat > "${DIST}" <<XML
<?xml version="1.0" encoding="utf-8"?>
<installer-gui-script minSpecVersion="2">
    <title>Šišana</title>
    <domains enable_anywhere="false" enable_currentUserHome="true" enable_localSystem="true"/>
    <options customize="never" require-scripts="false" rootVolumeOnly="false"/>
    <choices-outline>
        <line choice="default"><line choice="${PKG_ID}"/></line>
    </choices-outline>
    <choice id="default"/>
    <choice id="${PKG_ID}" visible="false">
        <pkg-ref id="${PKG_ID}"/>
    </choice>
    <pkg-ref id="${PKG_ID}" version="${VERSION}" onConclusion="none">$(basename "${COMPONENT}")</pkg-ref>
</installer-gui-script>
XML

# 5. Build the distribution pkg.
rm -f "${UNSIGNED}"
productbuild --distribution "${DIST}" --package-path "$(dirname "${COMPONENT}")" "${UNSIGNED}"

# 6. Sign with Developer ID Installer.
INST_ID="${IODIA_INSTALLER_ID:-}"
[ -z "${INST_ID}" ] && INST_ID="$(security find-identity -v | awk '/Developer ID Installer/ && !/Cubios/ {print $2; exit}')"
[ -z "${INST_ID}" ] && { echo "!! no Developer ID Installer identity" >&2; exit 1; }
echo "==> productsign: ${INST_ID}"
rm -f "${PKG}"
productsign --sign "${INST_ID}" "${UNSIGNED}" "${PKG}"
pkgutil --check-signature "${PKG}" | sed -n '1,4p'

# 7. Notarize + staple.
if [ "${IODIA_SKIP_NOTARIZE:-0}" = "1" ]; then
    echo "==> IODIA_SKIP_NOTARIZE=1 — signed pkg built, notarization skipped."
else
    echo "==> notarizing (a few minutes)..."
    xcrun notarytool submit "${PKG}" --keychain-profile "${NOTARY_PROFILE}" --wait
    xcrun stapler staple "${PKG}"
    xcrun stapler validate "${PKG}"
fi
echo "OK: ${PKG} ($(stat -f%z "${PKG}") bytes)"
