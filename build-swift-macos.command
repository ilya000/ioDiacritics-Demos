#!/usr/bin/env bash
# Compile the Swift / macOS demo from the repository root (no launch).
#
# Usage:
#   ./build-swift-macos.command          # from a terminal
#   (or double-click in Finder)
#
# Produces a signed app bundle at:  Swift-macOS/dist/ioDiacriticsDemo.app
# Requires: Xcode command-line tools (swift). Depends on the sibling ../ioDiacritics checkout.
set -euo pipefail
cd "$(dirname "$0")/Swift-macOS"

echo "==> compiling Swift/macOS demo (release)..."
./build_app.sh

echo
echo "OK. App bundle: $(pwd)/dist/ioDiacriticsDemo.app"
echo "    run it with:  ./run-swift-macos.command   (from the repo root)"
echo "    or:           open \"$(pwd)/dist/ioDiacriticsDemo.app\""
