// Generates AppIcon.iconset for the ioDiacritics demo: a bold white "Š" — the emblematic
// šišana/dešišavanje letter — on a gradient squircle, with a gold accent caron to spotlight the
// restored diacritic. Pure AppKit/CoreGraphics, no assets needed.
//
// Usage:  swift tools/make_icon.swift   (writes AppIcon.iconset/, then run iconutil to .icns)
import AppKit

let outDir = "AppIcon.iconset"
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

func render(_ px: Int) -> Data {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: px, height: px)

    NSGraphicsContext.saveGraphicsState()
    let gctx = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = gctx
    let cg = gctx.cgContext
    let N = CGFloat(px)
    cg.clear(CGRect(x: 0, y: 0, width: N, height: N))

    // Rounded-rect ("squircle"-ish) plate with a small transparent margin.
    let margin = N * 0.085
    let rect = CGRect(x: margin, y: margin, width: N - 2 * margin, height: N - 2 * margin)
    let radius = rect.width * 0.2237
    let plate = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)

    // Soft drop shadow under the plate.
    cg.saveGState()
    cg.setShadow(offset: CGSize(width: 0, height: -N * 0.012),
                 blur: N * 0.03, color: NSColor.black.withAlphaComponent(0.28).cgColor)
    cg.addPath(plate); cg.setFillColor(NSColor.black.cgColor); cg.fillPath()
    cg.restoreGState()

    // Diagonal gradient fill (indigo -> cyan).
    cg.saveGState()
    cg.addPath(plate); cg.clip()
    let cs = CGColorSpaceCreateDeviceRGB()
    let grad = CGGradient(colorsSpace: cs, colors: [
        NSColor(srgbRed: 0.42, green: 0.36, blue: 0.97, alpha: 1).cgColor,   // indigo
        NSColor(srgbRed: 0.10, green: 0.49, blue: 0.95, alpha: 1).cgColor,   // blue
        NSColor(srgbRed: 0.02, green: 0.74, blue: 0.83, alpha: 1).cgColor,   // cyan
    ] as CFArray, locations: [0.0, 0.55, 1.0])!
    cg.drawLinearGradient(grad, start: CGPoint(x: rect.minX, y: rect.maxY),
                          end: CGPoint(x: rect.maxX, y: rect.minY), options: [])
    // Glossy top highlight.
    let gloss = CGGradient(colorsSpace: cs, colors: [
        NSColor.white.withAlphaComponent(0.22).cgColor,
        NSColor.white.withAlphaComponent(0.0).cgColor,
    ] as CFArray, locations: [0.0, 1.0])!
    cg.drawLinearGradient(gloss, start: CGPoint(x: rect.midX, y: rect.maxY),
                          end: CGPoint(x: rect.midX, y: rect.midY), options: [])
    cg.restoreGState()

    // The letter "Š", centered, white with a subtle shadow. A gold caron is layered on top by
    // clipping to the upper band so only the háček (not the S body) is tinted.
    let fontSize = N * 0.60
    let font = NSFont.systemFont(ofSize: fontSize, weight: .bold)
    let baseShadow = NSShadow()
    baseShadow.shadowColor = NSColor.black.withAlphaComponent(0.28)
    baseShadow.shadowBlurRadius = N * 0.02
    baseShadow.shadowOffset = NSSize(width: 0, height: -N * 0.012)

    let white = NSAttributedString(string: "Š", attributes: [
        .font: font, .foregroundColor: NSColor.white, .shadow: baseShadow])
    let sz = white.size()
    let origin = CGPoint(x: (N - sz.width) / 2, y: (N - sz.height) / 2 - N * 0.015)
    white.draw(at: origin)

    // Gold caron: redraw the glyph clipped to the band ABOVE the S cap, so only the háček is
    // tinted (the S body stays white). The gap between the S top (~0.80 of the line box) and the
    // caron bottom lets us cut cleanly without nicking the letter.
    cg.saveGState()
    let band = CGRect(x: 0, y: origin.y + sz.height * 0.82, width: N, height: sz.height * 0.30)
    cg.clip(to: band)
    NSAttributedString(string: "Š", attributes: [
        .font: font,
        .foregroundColor: NSColor(srgbRed: 1.0, green: 0.82, blue: 0.25, alpha: 1.0),
    ]).draw(at: origin)
    cg.restoreGState()

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

// Standard .iconset members.
let entries: [(String, Int)] = [
    ("icon_16x16.png", 16), ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32), ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128), ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256), ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512), ("icon_512x512@2x.png", 1024),
]
for (name, px) in entries {
    let data = render(px)
    try! data.write(to: URL(fileURLWithPath: "\(outDir)/\(name)"))
    print("wrote \(outDir)/\(name) (\(px)px)")
}
print("Done. Now: iconutil -c icns \(outDir) -o AppIcon.icns")
