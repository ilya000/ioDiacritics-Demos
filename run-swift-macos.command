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

echo "==> launching ioDiacriticsDemo.app ..."
open "dist/ioDiacriticsDemo.app"
