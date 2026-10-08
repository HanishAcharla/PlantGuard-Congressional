// Renders the 1024x1024 app icon: a leaf inside "scan" corner brackets.
//   swift ios/scripts/render_icon.swift ios/PlantGuard/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png
import AppKit
import CoreGraphics

let size = 1024
let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.png"
let cs = CGColorSpace(name: CGColorSpace.sRGB)!
let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                    space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!

func rgb(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: a)
}

let S = CGFloat(size)

// Background: deep canopy gradient + soft glows.
let bg = CGGradient(colorsSpace: cs, colors: [rgb(0x16352A), rgb(0x0A1A12), rgb(0x060F0A)] as CFArray,
                    locations: [0, 0.6, 1])!
ctx.drawLinearGradient(bg, start: CGPoint(x: 0, y: S), end: CGPoint(x: S, y: 0), options: [])
let glowGreen = CGGradient(colorsSpace: cs, colors: [rgb(0x4C8F65, 0.55), rgb(0x4C8F65, 0)] as CFArray, locations: [0, 1])!
ctx.drawRadialGradient(glowGreen, startCenter: CGPoint(x: S * 0.32, y: S * 0.7), startRadius: 0,
                       endCenter: CGPoint(x: S * 0.32, y: S * 0.7), endRadius: S * 0.55, options: [])
let glowRust = CGGradient(colorsSpace: cs, colors: [rgb(0xC96A35, 0.45), rgb(0xC96A35, 0)] as CFArray, locations: [0, 1])!
ctx.drawRadialGradient(glowRust, startCenter: CGPoint(x: S * 0.82, y: S * 0.12), startRadius: 0,
                       endCenter: CGPoint(x: S * 0.82, y: S * 0.12), endRadius: S * 0.5, options: [])

// Leaf, rotated around the icon centre.
ctx.saveGState()
ctx.translateBy(x: S / 2, y: S / 2)
ctx.rotate(by: -0.62)
let L: CGFloat = 330  // half length
let W: CGFloat = 190  // half width
let leaf = CGMutablePath()
leaf.move(to: CGPoint(x: 0, y: -L))
leaf.addCurve(to: CGPoint(x: 0, y: L), control1: CGPoint(x: W * 1.55, y: -L * 0.55), control2: CGPoint(x: W * 0.9, y: L * 0.75))
leaf.addCurve(to: CGPoint(x: 0, y: -L), control1: CGPoint(x: -W * 0.9, y: L * 0.75), control2: CGPoint(x: -W * 1.55, y: -L * 0.55))
leaf.closeSubpath()

// Stem.
ctx.setStrokeColor(rgb(0x7FB896))
ctx.setLineWidth(22)
ctx.setLineCap(.round)
ctx.move(to: CGPoint(x: 0, y: -L * 0.9))
ctx.addQuadCurve(to: CGPoint(x: -26, y: -L * 1.22), control: CGPoint(x: 4, y: -L * 1.1))
ctx.strokePath()

ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -18), blur: 50, color: rgb(0x000000, 0.55))
ctx.addPath(leaf)
ctx.setFillColor(rgb(0x3E8A55))
ctx.fillPath()
ctx.restoreGState()

ctx.saveGState()
ctx.addPath(leaf)
ctx.clip()
let leafGrad = CGGradient(colorsSpace: cs, colors: [rgb(0xB5E3B0), rgb(0x6CBF7E), rgb(0x2F7A48)] as CFArray,
                          locations: [0, 0.45, 1])!
ctx.drawLinearGradient(leafGrad, start: CGPoint(x: -W, y: L), end: CGPoint(x: W, y: -L), options: [])

// Veins.
ctx.setStrokeColor(rgb(0xEAF7E4, 0.75))
ctx.setLineCap(.round)
ctx.setLineWidth(14)
ctx.move(to: CGPoint(x: 0, y: -L * 0.98))
ctx.addCurve(to: CGPoint(x: 0, y: L * 0.92), control1: CGPoint(x: 18, y: -L * 0.3), control2: CGPoint(x: 10, y: L * 0.4))
ctx.strokePath()
ctx.setLineWidth(8)
ctx.setStrokeColor(rgb(0xEAF7E4, 0.42))
// Lateral veins branch off the midrib and sweep toward the tip (+y).
for i in 0..<5 {
    let y = -L * 0.62 + CGFloat(i) * L * 0.28
    let reach = W * (1.05 - 0.13 * CGFloat(i))
    for side in [-1.0, 1.0] as [CGFloat] {
        ctx.move(to: CGPoint(x: 0, y: y))
        ctx.addQuadCurve(to: CGPoint(x: side * reach, y: y + L * 0.34),
                         control: CGPoint(x: side * reach * 0.55, y: y + L * 0.06))
        ctx.strokePath()
    }
}
// A couple of rust lesions.
for (x, y, r) in [(-70.0, 60.0, 34.0), (85.0, -120.0, 24.0), (40.0, 190.0, 18.0)] as [(CGFloat, CGFloat, CGFloat)] {
    ctx.setFillColor(rgb(0x7A2E12, 0.9))
    ctx.fillEllipse(in: CGRect(x: x - r * 1.25, y: y - r * 1.25, width: r * 2.5, height: r * 2.5))
    ctx.setFillColor(rgb(0xE8873F))
    ctx.fillEllipse(in: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
}
ctx.restoreGState()
ctx.restoreGState()

// Scan brackets.
ctx.setStrokeColor(rgb(0xF1A36B))
ctx.setLineWidth(34)
ctx.setLineCap(.round)
ctx.setLineJoin(.round)
let m: CGFloat = 150, len: CGFloat = 150
for (cx, cy, dx, dy) in [(m, m, 1.0, 1.0), (S - m, m, -1.0, 1.0), (m, S - m, 1.0, -1.0), (S - m, S - m, -1.0, -1.0)] as [(CGFloat, CGFloat, CGFloat, CGFloat)] {
    ctx.move(to: CGPoint(x: cx, y: cy + dy * len))
    ctx.addLine(to: CGPoint(x: cx, y: cy))
    ctx.addLine(to: CGPoint(x: cx + dx * len, y: cy))
    ctx.strokePath()
}

let image = ctx.makeImage()!
let rep = NSBitmapImageRep(cgImage: image)
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
print("wrote", out)
