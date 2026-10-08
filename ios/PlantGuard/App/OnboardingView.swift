import SwiftUI

struct OnboardingView: View {
    var onFinish: (_ withHistory: Bool) -> Void
    @State private var page = 0

    var body: some View {
        ZStack {
            AppBackground()
            VStack(spacing: 0) {
                TabView(selection: $page) {
                    DetectPage().tag(0)
                    TrackPage().tag(1)
                    TreatPage().tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                HStack(spacing: 8) {
                    ForEach(0..<3) { i in
                        Capsule().fill(i == page ? Theme.rustLight : Theme.parchment.opacity(0.2))
                            .frame(width: i == page ? 26 : 8, height: 8)
                    }
                }
                .animation(.spring(response: 0.4), value: page)
                .padding(.bottom, 24)

                VStack(spacing: 12) {
                    if page < 2 {
                        Button("Continue") { withAnimation(.snappy) { page += 1 } }
                            .buttonStyle(PrimaryButtonStyle())
                    } else {
                        Button {
                            onFinish(true)
                        } label: {
                            Label("Explore the demo orchard", systemImage: "sparkles")
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        Button("Start with an empty orchard") { onFinish(false) }
                            .buttonStyle(SecondaryButtonStyle())
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
                .animation(.snappy, value: page)
            }
        }
    }
}

private struct PageLayout<Art: View>: View {
    let kicker: String
    let title: String
    let message: String
    @ViewBuilder var art: Art

    var body: some View {
        VStack(spacing: 26) {
            Spacer(minLength: 20)
            art.frame(height: 300)
            VStack(spacing: 12) {
                Text(kicker).kickerStyle()
                Text(title).font(.display(34)).multilineTextAlignment(.center).foregroundStyle(Theme.textPrimary)
                Text(message).font(.system(size: 16)).multilineTextAlignment(.center).foregroundStyle(Theme.textSecondary)
                    .padding(.horizontal, 8)
            }
            .padding(.horizontal, 24)
            Spacer()
        }
    }
}

private struct DetectPage: View {
    @State private var index = 0
    @State private var sweep = false
    private let cycle: [Disease] = [.scab, .rust, .healthy, .powderyMildew, .frogEyeLeafSpot, .complex]

    var body: some View {
        PageLayout(kicker: "On-device AI", title: "Know what's on the leaf",
                   message: "A research-grade ResNet-50 runs right on your iPhone's Neural Engine. No signal needed in the orchard, and photos never leave the phone.") {
            ZStack {
                Circle().fill(cycle[index].color.opacity(0.18)).frame(width: 270).blur(radius: 40)
                LeafArt(disease: cycle[index], seed: index * 13 + 5, tilt: false)
                    .frame(width: 230, height: 230)
                    .id(index)
                    .transition(.asymmetric(insertion: .scale(scale: 0.85).combined(with: .opacity), removal: .opacity))
                ScanBrackets().frame(width: 250, height: 250)
                Rectangle()
                    .fill(LinearGradient(colors: [.clear, Theme.rustLight.opacity(0.85), .clear], startPoint: .leading, endPoint: .trailing))
                    .frame(width: 230, height: 2)
                    .shadow(color: Theme.rustLight, radius: 8)
                    .offset(y: sweep ? 110 : -110)
                VStack {
                    Spacer()
                    DiseaseBadge(disease: cycle[index]).id(index).transition(.move(edge: .bottom).combined(with: .opacity))
                }
                .frame(height: 300)
            }
            .onAppear { withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) { sweep = true } }
            .task {
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(1.8))
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { index = (index + 1) % cycle.count }
                }
            }
        }
    }
}

private struct TrackPage: View {
    @State private var season = 0
    private let pattern: [[Disease]] = (0..<3).map { s in
        var rng = SeededRandom(s * 97 + 11)
        return (0..<48).map { _ in
            let r = rng.unit()
            let sick = 0.12 + 0.1 * Double(s)
            return r < sick ? [Disease.scab, .rust, .powderyMildew][rng.int(0...2)] : .healthy
        }
    }

    var body: some View {
        PageLayout(kicker: "Every tree, every season", title: "Watch disease move",
                   message: "Map each tree, then replay the orchard season by season to see where infections start, spread, and come back.") {
            VStack(spacing: 16) {
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(30), spacing: 10), count: 8), spacing: 10) {
                    ForEach(0..<48, id: \.self) { i in
                        let d = pattern[season][i]
                        Circle()
                            .fill(d == .healthy ? Theme.sage.opacity(0.35) : d.color)
                            .frame(width: 22, height: 22)
                            .shadow(color: d == .healthy ? .clear : d.color.opacity(0.8), radius: 6)
                            .scaleEffect(d == .healthy ? 0.85 : 1.05)
                    }
                }
                HStack(spacing: 8) {
                    ForEach(0..<3) { s in
                        Text(["Spring", "Summer", "Fall"][s])
                            .font(.system(size: 12, weight: .semibold))
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .foregroundStyle(s == season ? Theme.canopy950 : Theme.textSecondary)
                            .background(Capsule().fill(s == season ? Theme.parchment : Theme.parchment.opacity(0.08)))
                    }
                }
            }
            .task {
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(1.4))
                    withAnimation(.spring(response: 0.6)) { season = (season + 1) % 3 }
                }
            }
        }
    }
}

private struct TreatPage: View {
    var body: some View {
        PageLayout(kicker: "Context, not guesswork", title: "Treat at the right time",
                   message: "Care plans adapt to the season and each tree's history, and an infection-risk forecast tells you when spraying actually matters.") {
            VStack(spacing: 12) {
                ForEach(Array(zip([Disease.scab, .rust, .powderyMildew], [RiskLevel.high, .moderate, .low]).enumerated()), id: \.offset) { i, pair in
                    GlassCard(padding: 14, cornerRadius: 20) {
                        HStack(spacing: 12) {
                            IconTile(symbol: pair.0.symbol, color: pair.0.color, size: 40)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(pair.0.name).font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.textPrimary)
                                Text(["Protect before Thursday's rain", "Galls releasing spores", "Too cool for mildew"][i])
                                    .font(.system(size: 12)).foregroundStyle(Theme.textSecondary)
                            }
                            Spacer()
                            Text(pair.1.label).font(.system(size: 12, weight: .bold))
                                .padding(.horizontal, 10).padding(.vertical, 5)
                                .foregroundStyle(pair.1.color)
                                .background(Capsule().fill(pair.1.color.opacity(0.15)))
                        }
                    }
                    .padding(.horizontal, 28)
                }
            }
        }
    }
}

struct ScanBrackets: View {
    var color: Color = Theme.rustLight
    var lineWidth: CGFloat = 4

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height, l = min(w, h) * 0.18
            Path { p in
                p.move(to: CGPoint(x: 0, y: l)); p.addLine(to: .zero); p.addLine(to: CGPoint(x: l, y: 0))
                p.move(to: CGPoint(x: w - l, y: 0)); p.addLine(to: CGPoint(x: w, y: 0)); p.addLine(to: CGPoint(x: w, y: l))
                p.move(to: CGPoint(x: w, y: h - l)); p.addLine(to: CGPoint(x: w, y: h)); p.addLine(to: CGPoint(x: w - l, y: h))
                p.move(to: CGPoint(x: l, y: h)); p.addLine(to: CGPoint(x: 0, y: h)); p.addLine(to: CGPoint(x: 0, y: h - l))
            }
            .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
            .shadow(color: color.opacity(0.6), radius: 6)
        }
    }
}
