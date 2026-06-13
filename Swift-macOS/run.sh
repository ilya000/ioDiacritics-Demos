#!/bin/bash
# Quick dev run: build + launch the .app. (`swift run` also works but a bundled .app gets
# a proper Dock icon and window focus.)
set -euo pipefail
cd "$(dirname "$0")"
./build_app.sh
open "dist/ioDiacriticsDemo.app"
