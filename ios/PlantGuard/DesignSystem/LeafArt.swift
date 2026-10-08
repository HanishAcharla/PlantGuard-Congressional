import SwiftUI

/// Small deterministic RNG so the same seed always draws the same leaf / generates the same demo orchard.
struct SeededRandom: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) { state = seed &+ 0x9E37_79B9_7F4A_7C15 }
    init(_ seed: Int) { self.init(seed: UInt64(bitPattern: Int64(seed))) }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    mutating func unit() -> Double { Double(next() >> 11) / Double(1 << 53) }
    mutating func range(_ r: ClosedRange<Double>) -> Double { r.lowerBound + unit() * (r.upperBound - r.lowerBound) }
    mutating func chance(_ p: Double) -> Bool { unit() < p }
    mutating func int(_ r: ClosedRange<Int>) -> Int { r.lowerBound + Int(unit() * Double(r.count)) }
}

/// A procedurally drawn apple leaf showing the lesions characteristic of `disease`.
struct LeafArt: View {
    var disease: Disease
    var seed: Int
    var tilt: Bool = true

    var body: some View {
        Canvas { ctx, size in
            LeafRenderer.draw(in: &ctx, size: size, disease: disease, seed: seed, tilt: tilt)
        }
        .drawingGroup()
    }
}

/// Shows the photo if there is one, otherwise the leaf illustration on a dark tile.
struct ScanThumbnail: View {
    let scan: Scan
    var cornerRadius: CGFloat = 14

    var body: some View {
        ZStack {
            if let data = scan.imageData, let image = UIImage(data: data) {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                LinearGradient(colors: [Theme.canopy700, Theme.canopy900], startPoint: .top, endPoint: .bottom)
                LeafArt(disease: scan.disease, seed: scan.artSeed).padding(4)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).strokeBorder(Theme.parchment.opacity(0.1), lineWidth: 0.8))
    }
}

enum LeafRenderer {
    static func outline(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        let cx = rect.midX
        let baseY = rect.minY + h * 0.88
        let tipY = rect.minY + h * 0.03
        let n = 70
        var right: [CGPoint] = []
        for i in 0...n {
            let u = Double(i) / Double(n)
            let y = baseY + (tipY - baseY) * u
            // Ovate: widest a little below the middle, rounded base, drawn-out pointed tip.
            var half = w * 0.40 * pow(sin(.pi * pow(u, 0.78)), 0.72) * (1 - 0.12 * u)
            if i % 2 == 1 && u > 0.12 && u < 0.96 { half -= w * 0.011 } // serrated margin
            right.append(CGPoint(x: cx + half, y: y))
        }
        var p = Path()
        p.move(to: right[0])
        for pt in right.dropFirst() { p.addLine(to: pt) }
        for pt in right.reversed().dropFirst() { p.addLine(to: CGPoint(x: 2 * cx - pt.x, y: pt.y)) }
        p.closeSubpath()
        return p
    }

    private static func palette(_ d: Disease) -> [Color] {
        switch d {
        case .healthy: [Color(hex: 0x9BD98A), Color(hex: 0x58A85A), Color(hex: 0x2D6E3A)]
        case .scab: [Color(hex: 0xA7C46E), Color(hex: 0x6D9947), Color(hex: 0x41642D)]
        case .rust: [Color(hex: 0xC2D36A), Color(hex: 0x86AB45), Color(hex: 0x4F7C2F)]
        case .powderyMildew: [Color(hex: 0xAFCBA4), Color(hex: 0x739F6E), Color(hex: 0x46714B)]
        case .frogEyeLeafSpot: [Color(hex: 0xB8C96E), Color(hex: 0x7F9D48), Color(hex: 0x52722F)]
        case .complex: [Color(hex: 0xC6C46A), Color(hex: 0x8E964A), Color(hex: 0x5C6B32)]
        }
    }

    static func draw(in ctx: inout GraphicsContext, size: CGSize, disease: Disease, seed: Int, tilt: Bool) {
        var rng = SeededRandom(seed &* 7919 &+ disease.rawValue.count)
        let side = min(size.width, size.height)
        let rect = CGRect(x: (size.width - side * 0.62) / 2, y: (size.height - side * 0.98) / 2, width: side * 0.62, height: side * 0.98)
        let leaf = outline(in: rect)
        let cx = rect.midX
        let baseY = rect.minY + rect.height * 0.88
        let tipY = rect.minY + rect.height * 0.03

        ctx.translateBy(x: size.width / 2, y: size.height / 2)
        ctx.rotate(by: .radians(tilt ? rng.range(-0.55...0.55) : 0))
        ctx.translateBy(x: -size.width / 2, y: -size.height / 2)

        // Stem.
        var stem = Path()
        stem.move(to: CGPoint(x: cx, y: baseY - 2))
        stem.addQuadCurve(to: CGPoint(x: cx - side * 0.05, y: rect.maxY + side * 0.01),
                          control: CGPoint(x: cx + side * 0.01, y: baseY + side * 0.06))
        ctx.stroke(stem, with: .color(Color(hex: 0x7C9A45)), style: StrokeStyle(lineWidth: max(1.2, side * 0.022), lineCap: .round))

        // Body with soft drop shadow.
        ctx.drawLayer { layer in
            layer.addFilter(.shadow(color: .black.opacity(0.35), radius: side * 0.04, y: side * 0.02))
            layer.fill(leaf, with: .linearGradient(Gradient(colors: palette(disease)),
                                                   startPoint: CGPoint(x: rect.minX, y: rect.minY),
                                                   endPoint: CGPoint(x: rect.maxX, y: rect.maxY)))
        }

        ctx.drawLayer { layer in
            layer.clip(to: leaf)
            drawLesions(&layer, disease: disease, rect: rect, rng: &rng, side: side)

            // Veins.
            let vein = Color(hex: 0xEAF5D6).opacity(disease == .powderyMildew ? 0.3 : 0.5)
            var mid = Path()
            mid.move(to: CGPoint(x: cx, y: baseY))
            mid.addQuadCurve(to: CGPoint(x: cx, y: tipY + rect.height * 0.04), control: CGPoint(x: cx + side * 0.02, y: (baseY + tipY) / 2))
            layer.stroke(mid, with: .color(vein), style: StrokeStyle(lineWidth: max(0.8, side * 0.012), lineCap: .round))
            for i in 0..<7 {
                let t = 0.14 + Double(i) * 0.11
                let y = baseY + (tipY - baseY) * t
                let reach = rect.width * (0.46 - 0.035 * Double(i))
                for s in [-1.0, 1.0] {
                    var v = Path()
                    v.move(to: CGPoint(x: cx + s * 1, y: y))
                    v.addQuadCurve(to: CGPoint(x: cx + s * reach, y: y - rect.height * 0.12),
                                   control: CGPoint(x: cx + s * reach * 0.5, y: y - rect.height * 0.015))
                    layer.stroke(v, with: .color(vein.opacity(0.7)), style: StrokeStyle(lineWidth: max(0.5, side * 0.006), lineCap: .round))
                }
            }

            // Gloss.
            layer.fill(Path(CGRect(x: rect.minX, y: rect.minY, width: rect.width * 0.5, height: rect.height)),
                       with: .linearGradient(Gradient(colors: [.white.opacity(0.14), .clear]),
                                             startPoint: CGPoint(x: rect.minX, y: rect.minY), endPoint: CGPoint(x: cx, y: rect.midY)))
        }
        ctx.stroke(leaf, with: .color(Color(hex: 0x24481F).opacity(0.55)), lineWidth: max(0.5, side * 0.005))
    }

    private static func point(in rect: CGRect, _ rng: inout SeededRandom) -> CGPoint {
        CGPoint(x: rect.minX + rect.width * rng.range(0.18...0.82), y: rect.minY + rect.height * rng.range(0.12...0.82))
    }

    private static func drawLesions(_ ctx: inout GraphicsContext, disease: Disease, rect: CGRect, rng: inout SeededRandom, side: CGFloat) {
        switch disease {
        case .healthy:
            break
        case .scab:
            scab(&ctx, rect: rect, rng: &rng, side: side, count: rng.int(6...10))
        case .rust:
            for _ in 0..<rng.int(5...9) {
                let c = point(in: rect, &rng)
                let r = side * rng.range(0.022...0.05)
                ctx.fill(Path(ellipseIn: CGRect(x: c.x - r * 1.5, y: c.y - r * 1.5, width: r * 3, height: r * 3)), with: .color(Color(hex: 0xD9C24A).opacity(0.35)))
                ctx.fill(Path(ellipseIn: CGRect(x: c.x - r * 1.18, y: c.y - r * 1.18, width: r * 2.36, height: r * 2.36)), with: .color(Color(hex: 0xA8361A)))
                ctx.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)),
                         with: .radialGradient(Gradient(colors: [Color(hex: 0xFFC44D), Color(hex: 0xF0802C)]), center: c, startRadius: 0, endRadius: r))
                for _ in 0..<3 {
                    let d = CGPoint(x: c.x + r * rng.range(-0.4...0.4), y: c.y + r * rng.range(-0.4...0.4))
                    ctx.fill(Path(ellipseIn: CGRect(x: d.x - r * 0.12, y: d.y - r * 0.12, width: r * 0.24, height: r * 0.24)), with: .color(Color(hex: 0x3A1406)))
                }
            }
        case .powderyMildew:
            ctx.drawLayer { layer in
                layer.addFilter(.blur(radius: side * 0.03))
                for _ in 0..<rng.int(4...6) {
                    let c = point(in: rect, &rng)
                    let r = side * rng.range(0.07...0.14)
                    layer.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r * 0.8, width: r * 2, height: r * 1.6)), with: .color(Color(hex: 0xEEF2F0).opacity(0.62)))
                }
            }
            for _ in 0..<70 {
                let c = point(in: rect, &rng)
                let r = side * rng.range(0.002...0.006)
                ctx.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)), with: .color(.white.opacity(0.55)))
            }
        case .frogEyeLeafSpot:
            frogEye(&ctx, rect: rect, rng: &rng, side: side, count: rng.int(5...8))
        case .complex:
            scab(&ctx, rect: rect, rng: &rng, side: side, count: rng.int(4...6))
            frogEye(&ctx, rect: rect, rng: &rng, side: side, count: rng.int(2...4))
            ctx.fill(Path(rect), with: .color(Color(hex: 0xC9A63A).opacity(0.12)))
        }
    }

    private static func scab(_ ctx: inout GraphicsContext, rect: CGRect, rng: inout SeededRandom, side: CGFloat, count: Int) {
        ctx.drawLayer { layer in
            layer.addFilter(.blur(radius: side * 0.006))
            for _ in 0..<count {
                let c = point(in: rect, &rng)
                let r = side * rng.range(0.025...0.06)
                for _ in 0..<5 {
                    let o = CGPoint(x: c.x + r * rng.range(-0.6...0.6), y: c.y + r * rng.range(-0.6...0.6))
                    let rr = r * rng.range(0.5...0.95)
                    layer.fill(Path(ellipseIn: CGRect(x: o.x - rr, y: o.y - rr * 0.85, width: rr * 2, height: rr * 1.7)),
                               with: .color(Color(hex: rng.chance(0.5) ? 0x4E4A22 : 0x5F5A2B).opacity(0.82)))
                }
            }
        }
    }

    private static func frogEye(_ ctx: inout GraphicsContext, rect: CGRect, rng: inout SeededRandom, side: CGFloat, count: Int) {
        for _ in 0..<count {
            let c = point(in: rect, &rng)
            let r = side * rng.range(0.022...0.045)
            let circle = Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
            ctx.fill(circle, with: .radialGradient(Gradient(colors: [Color(hex: 0xD8BC8C), Color(hex: 0xA77F5C)]), center: c, startRadius: 0, endRadius: r))
            ctx.stroke(circle, with: .color(Color(hex: 0x6A2754)), lineWidth: r * 0.32)
            ctx.stroke(Path(ellipseIn: CGRect(x: c.x - r * 0.55, y: c.y - r * 0.55, width: r * 1.1, height: r * 1.1)),
                       with: .color(Color(hex: 0x8A6448).opacity(0.7)), lineWidth: r * 0.1)
        }
    }
}
