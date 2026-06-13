#!/usr/bin/env bash
# Compile AND launch the Swift / macOS demo from the repository root.
#
# Usage:
#   ./run-swift-macos.command            # from a terminal
#   (or double-click in Finder)
#
# Builds Swift-macOS/dist/ioDiacriticsDemo.app, then opens it.
# Requires: Xcode command-line tools (swift). Depends on the sibling ../ioDiacritics checkout.
set -euo pipefail
cd "$(dirname "$0")/Swift-macOS"

echo "==> compiling Swift/macOS demo (release)..."
./build_app.sh

# IMPORTANT: `open` on an already-running app just re-activates the OLD instance — it does NOT
# load the freshly built binary. Quit any running copy first so the new build actually runs.
echo "==> quitting any running instance..."
osascript -e 'tell application "ioDiacriticsDemo" to quit' 2>/dev/null || true
pkill -x ioDiacriticsDemo 2>/dev/null || true
sleep 0.6

echo "==> launching ioDiacriticsDemo.app ..."
open -n "dist/ioDiacriticsDemo.app"
