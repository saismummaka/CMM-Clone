import AppKit
import CoreGraphics
import Foundation

func drawIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    guard let ctx = NSGraphicsContext.current?.cgContext else { image.unlockFocus(); return image }

    let rect = CGRect(x: 0, y: 0, width: size, height: size)

    // Rounded square clip
    let cornerRadius: CGFloat = size * 0.22
    let path = CGPath(roundedRect: rect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
    ctx.addPath(path)
    ctx.clip()

    // Gradient background
    let colors = [
        NSColor(calibratedRed: 0.416, green: 0.353, blue: 0.804, alpha: 1.0).cgColor, // indigo
        NSColor(calibratedRed: 0.255, green: 0.412, blue: 0.882, alpha: 1.0).cgColor, // royal blue
        NSColor(calibratedRed: 0.118, green: 0.565, blue: 1.000, alpha: 1.0).cgColor  // dodger blue
    ] as CFArray
    let locations: [CGFloat] = [0.0, 0.5, 1.0]
    let space = CGColorSpaceCreateDeviceRGB()
    if let gradient = CGGradient(colorsSpace: space, colors: colors, locations: locations) {
        ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: size), end: CGPoint(x: size, y: 0), options: [])
    }

    // Top-left shine
    if let radial = CGGradient(
        colorsSpace: space,
        colors: [
            NSColor(white: 1, alpha: 0.35).cgColor,
            NSColor(white: 1, alpha: 0).cgColor
        ] as CFArray,
        locations: [0, 1]
    ) {
        ctx.drawRadialGradient(
            radial,
            startCenter: CGPoint(x: size * 0.3, y: size * 0.8),
            startRadius: 0,
            endCenter: CGPoint(x: size * 0.3, y: size * 0.8),
            endRadius: size * 0.6,
            options: []
        )
    }

    // Sparkle shape at center
    let center = CGPoint(x: size / 2, y: size / 2)
    ctx.saveGState()
    ctx.translateBy(x: center.x, y: center.y)

    let r: CGFloat = size * 0.24
    let c: CGFloat = size * 0.095
    let o: CGFloat = size * 0.023

    let sparklePath = CGMutablePath()
    sparklePath.move(to: CGPoint(x: 0, y: r))
    sparklePath.addCurve(to: CGPoint(x: r, y: 0),
                         control1: CGPoint(x: o, y: c),
                         control2: CGPoint(x: c, y: o))
    sparklePath.addCurve(to: CGPoint(x: 0, y: -r),
                         control1: CGPoint(x: c, y: -o),
                         control2: CGPoint(x: o, y: -c))
    sparklePath.addCurve(to: CGPoint(x: -r, y: 0),
                         control1: CGPoint(x: -o, y: -c),
                         control2: CGPoint(x: -c, y: -o))
    sparklePath.addCurve(to: CGPoint(x: 0, y: r),
                         control1: CGPoint(x: -c, y: o),
                         control2: CGPoint(x: -o, y: c))
    sparklePath.closeSubpath()

    ctx.addPath(sparklePath)
    ctx.setFillColor(NSColor(white: 1, alpha: 0.95).cgColor)
    ctx.fillPath()

    // Small satellite sparkles
    func drawSmallSparkle(at pt: CGPoint, scale: CGFloat, alpha: CGFloat) {
        ctx.saveGState()
        ctx.translateBy(x: pt.x, y: pt.y)
        ctx.scaleBy(x: scale, y: scale)
        let sr: CGFloat = size * 0.09
        let sc: CGFloat = size * 0.035
        let so: CGFloat = size * 0.009
        let p = CGMutablePath()
        p.move(to: CGPoint(x: 0, y: sr))
        p.addCurve(to: CGPoint(x: sr, y: 0),
                   control1: CGPoint(x: so, y: sc),
                   control2: CGPoint(x: sc, y: so))
        p.addCurve(to: CGPoint(x: 0, y: -sr),
                   control1: CGPoint(x: sc, y: -so),
                   control2: CGPoint(x: so, y: -sc))
        p.addCurve(to: CGPoint(x: -sr, y: 0),
                   control1: CGPoint(x: -so, y: -sc),
                   control2: CGPoint(x: -sc, y: -so))
        p.addCurve(to: CGPoint(x: 0, y: sr),
                   control1: CGPoint(x: -sc, y: so),
                   control2: CGPoint(x: -so, y: sc))
        p.closeSubpath()
        ctx.addPath(p)
        ctx.setFillColor(NSColor(white: 1, alpha: alpha).cgColor)
        ctx.fillPath()
        ctx.restoreGState()
    }

    drawSmallSparkle(at: CGPoint(x: -r * 1.15, y: r * 0.75), scale: 0.9, alpha: 0.85)
    drawSmallSparkle(at: CGPoint(x: r * 1.1, y: -r * 0.85), scale: 0.75, alpha: 0.75)

    ctx.restoreGState()

    // Top inner highlight
    ctx.saveGState()
    ctx.addPath(path)
    ctx.clip()
    let highlightRect = CGRect(x: 0, y: size * 0.5, width: size, height: size * 0.5)
    ctx.setFillColor(NSColor(white: 1, alpha: 0.04).cgColor)
    ctx.fill(highlightRect)
    ctx.restoreGState()

    image.unlockFocus()
    return image
}

func savePNG(_ image: NSImage, size: CGFloat, to path: String) {
    let pixelSize = Int(size)
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixelSize,
        pixelsHigh: pixelSize,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .calibratedRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!
    rep.size = NSSize(width: size, height: size)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    image.draw(in: NSRect(x: 0, y: 0, width: size, height: size),
               from: .zero, operation: .copy, fraction: 1.0)
    NSGraphicsContext.restoreGraphicsState()
    let data = rep.representation(using: .png, properties: [:])!
    try! data.write(to: URL(fileURLWithPath: path))
}

let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "./AppIcon.iconset"
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

let sizes: [(name: String, size: CGFloat)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

for (name, s) in sizes {
    let img = drawIcon(size: s)
    savePNG(img, size: s, to: "\(outDir)/\(name)")
    print("wrote \(name)")
}
