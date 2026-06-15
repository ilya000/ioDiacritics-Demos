#!/bin/bash
# Install the input method for the current user. For public distribution, use a signed and
# notarized bundle/DMG instead of this development helper.
set -euo pipefail

cd "$(dirname "$0")"
./build_app.sh

DEST="${HOME}/Library/Input Methods"
mkdir -p "${DEST}"
rm -rf "${DEST}/Šišana.app"
cp -R "dist/Šišana.app" "${DEST}/"

echo "Installed: ${DEST}/Šišana.app"
echo "Restarting TextInputMenuAgent..."
killall TextInputMenuAgent 2>/dev/null || true
echo "Now add 'Šišana' in System Settings -> Keyboard -> Input Sources."

