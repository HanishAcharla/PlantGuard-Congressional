import SwiftUI

/// Offline, zoomable plan of the orchard drawn in the planting grid's own frame (north up).
struct SchematicMapView: View {
    let orchard: Orchard
    let trees: [Tree]
    let status: [String: Disease]
    let hidden: Set<Disease>
    let selectedCode: String?
    let route: [Tree]
    var insets = EdgeInsets(top: 205, leading: 18, bottom: 290, trailing: 22)
    var onSelect: (String?) -> Void

    @State private var zoom: CGFloat = 1
    @State private var pan: CGSize = .zero
    @GestureState private var pinch: CGFloat = 1
    @GestureState private var drag: CGSize = .zero

    private struct Frame {
        let minX, maxY, scale: CGFloat
        let origin: CGPoint
        func point(_ x: Double, _ y: Double) -> CGPoint {
            CGPoint(x: origin.x + (CGFloat(x) - minX) * scale, y: origin.y + (maxY - CGFloat(y)) * scale)
        }
        func local(_ p: CGPoint) -> (x: Double, y: Double) {
            (Double((p.x - origin.x) / scale + minX), Double(maxY - (p.y - origin.y) / scale))
        }
    }

    private func frame(in size: CGSize) -> Frame {
        let xs = trees.map(\.localX) + [DemoSeeder.windbreakX]
        let ys = trees.map(\.localY)
        let minX = CGFloat((xs.min() ?? 0) - 6), maxX = CGFloat((xs.max() ?? 60) + 4)
        let minY = CGFloat((ys.min() ?? 0) - 6), maxY = CGFloat((ys.max() ?? 80) + 8)
        let availW = size.width - insets.leading - insets.trailing
        let availH = size.height - insets.top - insets.bottom
        let base = min(availW / (maxX - minX), availH / (maxY - minY))
        let k = base * zoom * pinch
        let w = (maxX - minX) * k, h = (maxY - minY) * k
        let origin = CGPoint(x: insets.leading + (availW - w) / 2 + pan.width + drag.width,
                             y: insets.top + (availH - h) / 2 + pan.height + drag.height)
        return Frame(minX: minX, maxY: maxY, scale: k, origin: origin)
    }

    var body: some View {
        GeometryReader { geo in
            let f = frame(in: geo.size)
            ZStack {
                Canvas { ctx, _ in draw(&ctx, f) }
                if let code = selectedCode, let tree = trees.first(where: { $0.code == code }) {
                    PulsingMarker(color: status[code]?.color ?? Theme.parchment, size: max(26, f.scale * 3.4))
                        .position(f.point(tree.localX, tree.localY))
                        .allowsHitTesting(false)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                SimultaneousGesture(
                    MagnifyGesture()
                        .updating($pinch) { v, s, _ in s = v.magnification }
                        .onEnded { v in zoom = min(6, max(0.7, zoom * v.magnification)) },
                    DragGesture()
                        .updating($drag) { v, s, _ in s = v.translation }
                        .onEnded { v in pan.width += v.translation.width; pan.height += v.translation.height }
                )
            )
            .onTapGesture(count: 2) {
                withAnimation(.spring(response: 0.45)) { zoom = 1; pan = .zero }
            }
            .onTapGesture { location in
                let p = f.local(location)
                let hit = trees.min { hypot($0.localX - p.x, $0.localY - p.y) < hypot($1.localX - p.x, $1.localY - p.y) }
                if let hit, hypot(hit.localX - p.x, hit.localY - p.y) < max(1.8, 14 / Double(f.scale)) {
                    Haptics.tap()
                    onSelect(hit.code)
                } else {
                    onSelect(nil)
                }
            }
        }
    }

    private func draw(_ ctx: inout GraphicsContext, _ f: Frame) {
        let k = f.scale

        // Cedar windbreak along the east fence.
        let ys = trees.map(\.localY)
        let top = (ys.max() ?? 80) + 4, bottom = (ys.min() ?? 0) - 3
        var y = bottom
        var stagger = false
        while y <= top {
            // Conical cedars, staggered in two loose lines.
            let p = f.point(DemoSeeder.windbreakX + (stagger ? 1.1 : -0.4), y)
            let r = max(2, 1.05 * k)
            var cone = Path()
            cone.move(to: CGPoint(x: p.x, y: p.y - r * 1.5))
            cone.addLine(to: CGPoint(x: p.x + r, y: p.y + r))
            cone.addLine(to: CGPoint(x: p.x - r, y: p.y + r))
            cone.closeSubpath()
            ctx.fill(cone, with: .color(Color(hex: 0x24452F)))
            ctx.stroke(cone, with: .color(Color(hex: 0x4A7A55).opacity(0.6)), lineWidth: 0.7)
            y += 3.2
            stagger.toggle()
        }
        let wbLabel = f.point(DemoSeeder.windbreakX + 1.5, bottom - 2.5)
        ctx.draw(Text("Cedar windbreak").font(.system(size: 10, weight: .semibold)).foregroundColor(Theme.sage.opacity(0.75)),
                 at: wbLabel, anchor: .topTrailing)

        // Blocks.
        for block in orchard.blocks.sorted(by: { $0.letter < $1.letter }) {
            let tl = f.point(block.originX - 1.2, block.originY + block.length + 1.2)
            let br = f.point(block.originX + block.width + 1.2, block.originY - 1.2)
            let rect = CGRect(x: tl.x, y: tl.y, width: br.x - tl.x, height: br.y - tl.y)
            let shape = Path(roundedRect: rect, cornerRadius: max(6, k * 1.5))
            ctx.fill(shape, with: .linearGradient(Gradient(colors: [Color(hex: 0x1B3A28).opacity(0.85), Color(hex: 0x10251A).opacity(0.85)]),
                                                  startPoint: rect.origin, endPoint: CGPoint(x: rect.maxX, y: rect.maxY)))
            ctx.stroke(shape, with: .color(Theme.parchment.opacity(0.14)), lineWidth: 1)
            // Row strips.
            for r in 0..<block.rows {
                let x = block.originX + (Double(r) + 0.5) * block.rowSpacing
                var line = Path()
                line.move(to: f.point(x, block.originY + 0.4))
                line.addLine(to: f.point(x, block.originY + block.length - 0.4))
                ctx.stroke(line, with: .color(Color(hex: 0x2C5A3C).opacity(0.7)), style: StrokeStyle(lineWidth: max(1, k * 1.6), lineCap: .round))
            }
            ctx.draw(Text("\(block.letter)  \(block.name)").font(.system(size: 11, weight: .bold)).foregroundColor(Theme.parchment.opacity(0.75)),
                     at: CGPoint(x: rect.minX + 6, y: rect.minY - 4), anchor: .bottomLeading)
            ctx.draw(Text(verbatim: "\(block.variety) · planted \(block.plantedYear)").font(.system(size: 9)).foregroundColor(Theme.parchment.opacity(0.4)),
                     at: CGPoint(x: rect.minX + 6, y: rect.maxY + 4), anchor: .topLeading)
        }

        // Inspection route.
        if !route.isEmpty {
            var path = Path()
            path.move(to: f.point(-3, -3))
            for t in route { path.addLine(to: f.point(t.localX, t.localY)) }
            ctx.stroke(path, with: .color(Theme.rustLight.opacity(0.9)), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round, dash: [5, 4]))
        }

        // Trees.
        let r = max(2.6, 1.05 * k)
        for tree in trees {
            let p = f.point(tree.localX, tree.localY)
            let d = status[tree.code]
            let dimmed = d.map { hidden.contains($0) } ?? false
            let circle = Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2))
            if let d, d.isDisease, !dimmed {
                let g = r * 2.3
                ctx.fill(Path(ellipseIn: CGRect(x: p.x - g, y: p.y - g, width: g * 2, height: g * 2)),
                         with: .radialGradient(Gradient(colors: [d.color.opacity(0.5), d.color.opacity(0)]), center: p, startRadius: 0, endRadius: g))
            }
            let fill: Color = d.map { $0 == .healthy ? Color(hex: 0x5DAF78) : $0.color } ?? Color(hex: 0x3B5446)
            ctx.fill(circle, with: .color(fill.opacity(dimmed ? 0.18 : 1)))
            ctx.stroke(circle, with: .color(.black.opacity(0.35)), lineWidth: 0.6)
        }

        // Route stop numbers.
        if !route.isEmpty && k > 5 {
            for (i, t) in route.enumerated() {
                let p = f.point(t.localX, t.localY)
                ctx.draw(Text("\(i + 1)").font(.system(size: 9, weight: .heavy)).foregroundColor(.white),
                         at: CGPoint(x: p.x + r + 5, y: p.y - r - 3))
            }
        }
    }
}

struct PulsingMarker: View {
    let color: Color
    var size: CGFloat = 30
    @State private var animate = false

    var body: some View {
        ZStack {
            Circle().stroke(color, lineWidth: 2)
                .frame(width: size, height: size)
                .scaleEffect(animate ? 1.7 : 0.7)
                .opacity(animate ? 0 : 0.9)
            Circle().strokeBorder(.white, lineWidth: 2.5)
                .frame(width: size * 0.62, height: size * 0.62)
                .shadow(color: color, radius: 6)
        }
        .onAppear { withAnimation(.easeOut(duration: 1.3).repeatForever(autoreverses: false)) { animate = true } }
    }
}
