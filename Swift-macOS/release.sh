#!/bin/bash
# Build a DISTRIBUTABLE, signed + notarized DMG of the Swift/macOS demo, for handing out to
# anyone. This is a PERSONAL project: it signs with a *personal* Developer ID and explicitly
# refuses the Cubios Inc business certificate.
#
# One-time setup (do this once on the machine):
#   1. Have a PERSONAL paid Apple Developer account (Apple Developer Program, $99/yr).
#   2. Create a "Developer ID Application" certificate under that personal account
#      (Xcode ▸ Settings ▸ Accounts ▸ Manage Certificates ▸ +, or developer.apple.com).
#      It lands in the keychain as: Developer ID Application: <Your Name> (<TEAMID>)
#   3. Store notarization credentials in the keychain (app-specific password from
#      appleid.apple.com ▸ Sign-In and Security ▸ App-Specific Passwords):
#        xcrun notarytool store-credentials "iodia-notary" \
#          --apple-id "<your-apple-id-email>" --team-id "<YOUR_TEAMID>" \
#          --password "<app-specific-password>"
#
# Then just run:  ./release.sh
#
# Overrides:
#   IODIA_SIGN_ID=<hash-or-name>     pick the signing identity explicitly
#   IODIA_NOTARY_PROFILE=<name>      notarytool keychain profile (default: iodia-notary)
#   IODIA_SKIP_NOTARIZE=1            sign + build the DMG but skip notarization/staple
set -euo pipefail
cd "$(dirname "$0")"

APP="dist/ioDiacriticsDemo.app"
DMG="dist/ioDiacriticsDemo.dmg"
VOLNAME="ioDiacritics Demo"
NOTARY_PROFILE="${IODIA_NOTARY_PROFILE:-iodia-notary}"

# 1. Build the .app (ad-hoc signed inside build_app.sh; we re-sign below).
./build_app.sh

# 2. Resolve a PERSONAL Developer ID Application identity. Never the Cubios business cert.
SIGN_ID="${IODIA_SIGN_ID:-}"
if [ -z "${SIGN_ID}" ]; then
    SIGN_ID="$(security find-identity -v -p codesigning \
        | awk '/Developer ID Application/ && !/Cubios/ {print $2; exit}')"
fi
if [ -z "${SIGN_ID}" ]; then
    echo "!! No PERSONAL 'Developer ID Application' identity found." >&2
    echo "   (The Cubios Inc business certificate is intentionally NOT used for this personal project.)" >&2
    echo "   Create a personal Developer ID cert, then re-run — or pass IODIA_SIGN_ID=<hash>." >&2
    exit 1
fi
echo "==> signing with: ${SIGN_ID}"

# 3. Sign the app with the hardened runtime + a secure timestamp (both required for notarization).
codesign --force --options runtime --timestamp --sign "${SIGN_ID}" "${APP}"
codesign --verify --strict --verbose=2 "${APP}"

# 4. Package a compressed DMG containing the app.
echo "==> building ${DMG} ..."
rm -f "${DMG}"
hdiutil create -volname "${VOLNAME}" -srcfolder "${APP}" -ov -format UDZO "${DMG}" >/dev/null
codesign --force --timestamp --sign "${SIGN_ID}" "${DMG}"

# 5. Notarize the DMG and staple the ticket (so it opens with no Gatekeeper prompt, offline too).
if [ "${IODIA_SKIP_NOTARIZE:-0}" = "1" ]; then
    echo "==> IODIA_SKIP_NOTARIZE=1 — signed DMG built, notarization skipped."
elif xcrun notarytool history --keychain-profile "${NOTARY_PROFILE}" >/dev/null 2>&1; then
    echo "==> notarizing (profile: ${NOTARY_PROFILE}) — this can take a few minutes..."
    xcrun notarytool submit "${DMG}" --keychain-profile "${NOTARY_PROFILE}" --wait
    echo "==> stapling..."
    xcrun stapler staple "${DMG}"
    xcrun stapler validate "${DMG}"
    echo "==> Gatekeeper assessment:"
    spctl --assess -vvv --type open --context context:primary-signature "${DMG}" || true
else
    echo "!! notarytool profile '${NOTARY_PROFILE}' not set up — DMG is signed but NOT notarized." >&2
    echo "   one-time: xcrun notarytool store-credentials \"${NOTARY_PROFILE}\" \\" >&2
    echo "               --apple-id <id> --team-id <TEAMID> --password <app-specific-password>" >&2
fi

echo "OK: ${PWD}/${DMG}"
