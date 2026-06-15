#!/usr/bin/env bash
# Build a signed, styled drag-install DMG for the Šišana input method:
# a window with Šišana.app on the left, an "Input Methods" folder on the right, and an arrow
# between them — the user drags the app into the folder. The target is /Library/Input Methods
# (system-wide; macOS asks for the admin password on drop). Unlike a .pkg this needs only the
# Developer ID *Application* cert (no Installer cert), so it can be notarized today.
#
# Layout is produced headlessly by `dmgbuild` (writes .DS_Store directly, no Finder).
#
# Usage:  ./make_dmg.sh        →  dist/Sisana-InputMethod.dmg  (signed; notarize separately)
# Override: IODIA_SIGN_ID=<hash>
set -euo pipefail
cd "$(dirname "$0")"

APP="dist/Šišana.app"
DMG="dist/Sisana-InputMethod.dmg"
VOLNAME="Šišana"
BG="/tmp/sisana_dmg_bg.png"
SETTINGS="/tmp/sisana_dmg_settings.py"

DMGBUILD=()
if command -v dmgbuild >/dev/null 2>&1; then
    DMGBUILD=(dmgbuild)
elif python3 -m dmgbuild --help >/dev/null 2>&1; then
    DMGBUILD=(python3 -m dmgbuild)
else
    echo "!! dmgbuild is required. Install it with: python3 -m pip install --user dmgbuild" >&2
    exit 1
fi

# 1. Build + Developer ID-sign the app (hardened runtime + timestamp).
./build_app.sh
SIGN_ID="${IODIA_SIGN_ID:-}"
[ -z "${SIGN_ID}" ] && SIGN_ID="$(security find-identity -v -p codesigning | awk '/Developer ID Application/ && !/Cubios/ {print $2; exit}')"
[ -z "${SIGN_ID}" ] && { echo "!! no personal Developer ID Application identity" >&2; exit 1; }
echo "==> signing app: ${SIGN_ID}"
codesign --force --deep --options runtime --timestamp --sign "${SIGN_ID}" "${APP}"
codesign --verify --deep --strict "${APP}"

# 2. Generate the background (arrow: app → Input Methods).
swift - "$BG" <<'SWIFT'
import AppKit
let out = CommandLine.arguments[1]
let W = 600.0, H = 400.0
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(W), pixelsHigh: Int(H),
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let cg = NSGraphicsContext.current!.cgContext
// soft vertical gradient background
let cs = CGColorSpaceCreateDeviceRGB()
let g = CGGradient(colorsSpace: cs, colors: [
    NSColor(srgbRed:0.97,green:0.98,blue:1.0,alpha:1).cgColor,
    NSColor(srgbRed:0.90,green:0.93,blue:0.98,alpha:1).cgColor] as CFArray, locations:[0,1])!
cg.drawLinearGradient(g, start: CGPoint(x:0,y:H), end: CGPoint(x:0,y:0), options: [])
// arrow (app at ~150 → folder at ~450, icons centred at y≈185 from top → CG y = H-185)
let yc = H - 195.0
cg.setStrokeColor(NSColor(srgbRed:0.20,green:0.45,blue:0.85,alpha:1).cgColor)
cg.setFillColor(NSColor(srgbRed:0.20,green:0.45,blue:0.85,alpha:1).cgColor)
cg.setLineWidth(10); cg.setLineCap(.round)
cg.move(to: CGPoint(x:250,y:yc)); cg.addLine(to: CGPoint(x:350,y:yc)); cg.strokePath()
cg.move(to: CGPoint(x:368,y:yc)); cg.addLine(to: CGPoint(x:344,y:yc+16)); cg.addLine(to: CGPoint(x:344,y:yc-16)); cg.closePath(); cg.fillPath()
func text(_ s:String,_ x:CGFloat,_ y:CGFloat,_ size:CGFloat,_ col:NSColor,_ center:Bool){
    let p=NSMutableParagraphStyle(); p.alignment = center ? .center : .left
    let a:[NSAttributedString.Key:Any]=[.font:NSFont.systemFont(ofSize:size,weight:.semibold),.foregroundColor:col,.paragraphStyle:p]
    let str=NSAttributedString(string:s,attributes:a); let sz=str.size()
    str.draw(at: CGPoint(x: center ? x - sz.width/2 : x, y: y - sz.height/2))
}
text("Install Šišana — drag it into the Input Methods folder", W/2, H-44, 17, NSColor(srgbRed:0.12,green:0.16,blue:0.24,alpha:1), true)
text("you may be asked for your admin password", W/2, H-70, 12.5, NSColor(srgbRed:0.45,green:0.5,blue:0.58,alpha:1), true)
text("Šišana", 150, 110, 13, NSColor.darkGray, true)
text("Input Methods", 450, 110, 13, NSColor.darkGray, true)
NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
print("bg ->", out)
SWIFT

# 3. dmgbuild settings.
cat > "$SETTINGS" <<PY
import os
app = os.environ["DMG_APP"]
app_name = os.path.basename(app)
format = "UDZO"
files = [app]
symlinks = {"Input Methods": "/Library/Input Methods"}
background = os.environ["DMG_BG"]
icon_size = 128
window_rect = ((200, 200), (600, 400))
icon_locations = { app_name: (150, 185), "Input Methods": (450, 185) }
PY

# 4. Build the styled DMG headlessly.
rm -f "$DMG"
DMG_APP="$APP" DMG_BG="$BG" "${DMGBUILD[@]}" -s "$SETTINGS" "$VOLNAME" "$DMG"

# 5. Sign the DMG (Developer ID Application — enough for notarization; no Installer cert needed).
codesign --force --timestamp --sign "${SIGN_ID}" "${DMG}"
echo "OK: ${DMG}  ($(stat -f%z "$DMG") bytes) — now notarize + staple separately."
