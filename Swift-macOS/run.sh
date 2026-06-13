#!/bin/bash
# Quick dev run: build + launch the .app. (`swift run` also works but a bundled .app gets
# a proper Dock icon and window focus.)
set -euo pipefail
cd "$(dirname "$0")"
./build_app.sh
# `open` on an already-running app re-activates the old instance instead of loading the new
# binary — quit any running copy first.
osascript -e 'tell application "ioDiacriticsDemo" to quit' 2>/dev/null || true
pkill -x ioDiacriticsDemo 2>/dev/null || true
sleep 0.6
open -n "dist/ioDiacriticsDemo.app"
