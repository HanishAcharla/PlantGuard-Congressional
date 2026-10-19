import SwiftUI

/// Slowly drifting mesh gradient — the canopy-at-dusk backdrop behind every screen.
struct AppBackground: View {
    var accent: Color = Theme.rust

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 15)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            MeshGradient(
                width: 3, height: 3,
                points: [
                    [0, 0], [0.5, 0], [1, 0],
                    [0, Float(0.48 + 0.06 * sin(t * 0.21))],
                    [Float(0.52 + 0.14 * sin(t * 0.13)), Float(0.44 + 0.12 * cos(t * 0.17))],
                    [1, Float(0.52 + 0.07 * cos(t * 0.19))],
                    [0, 1], [0.5, 1], [1, 1],
                ],
                colors: [
                    Color(hex: 0x173A2A), Theme.canopy850, Theme.canopy950,
                    Theme.canopy900, Color(hex: 0x123323), Theme.canopy950,
                    Theme.canopy950, accent.mix(with: Theme.canopy950, by: 0.82), Theme.canopy950,
                ]
            )
        }
        .ignoresSafeArea()
    }
}

struct GlassCard<Content: View>: View {
    var padding: CGFloat = 18
    var cornerRadius: CGFloat = 26
    var tint: Color? = nil
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(LinearGradient(colors: [(tint ?? Theme.canopy700).opacity(0.38), Theme.canopy950.opacity(0.55)],
                                                 startPoint: .topLeading, endPoint: .bottomTrailing))
                    )
            }
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(LinearGradient(colors: [Theme.parchment.opacity(0.16), Theme.parchment.opacity(0.03)],
                                                 startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.28), radius: 18, y: 10)
    }
}

struct SectionHeader: View {
    let kicker: String?
    let title: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .lastTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                if let kicker { Text(kicker).kickerStyle() }
                Text(title).font(.display(24)).foregroundStyle(Theme.textPrimary)
            }
            Spacer()
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.rustLight)
            }
        }
    }
}

struct DiseaseBadge: View {
    let disease: Disease
    var compact = false

    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(disease.color).frame(width: 7, height: 7)
                .shadow(color: disease.color.opacity(0.8), radius: 4)
            Text(compact ? disease.shortName : disease.name)
                .font(.system(size: compact ? 11 : 12, weight: .semibold))
        }
        .foregroundStyle(disease.color.mix(with: Theme.parchment, by: 0.35))
        .padding(.horizontal, compact ? 8 : 10)
        .padding(.vertical, compact ? 4 : 6)
        .background(Capsule().fill(disease.color.opacity(0.16)))
        .overlay(Capsule().strokeBorder(disease.color.opacity(0.28), lineWidth: 0.6))
    }
}

struct FilterChip: View {
    let title: String
    var color: Color = Theme.parchment
    var isOn: Bool
    var action: () -> Void

    var body: some View {
        Button(action: { Haptics.tap(); action() }) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .foregroundStyle(isOn ? Theme.canopy950 : Theme.textSecondary)
                .background(Capsule().fill(isOn ? AnyShapeStyle(color.mix(with: Theme.parchment, by: 0.5)) : AnyShapeStyle(Theme.parchment.opacity(0.07))))
                .overlay(Capsule().strokeBorder(Theme.parchment.opacity(isOn ? 0 : 0.1), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .animation(.snappy(duration: 0.25), value: isOn)
    }
}

struct ConfidenceRing: View {
    let value: Double
    var color: Color
    var lineWidth: CGFloat = 10
    @State private var shown: Double = 0

    var body: some View {
        ZStack {
            Circle().stroke(Theme.parchment.opacity(0.08), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: shown)
                .stroke(AngularGradient(colors: [color.opacity(0.4), color, color.mix(with: .white, by: 0.25)], center: .center),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .shadow(color: color.opacity(0.55), radius: 8)
        }
        .onAppear { withAnimation(.spring(response: 1.1, dampingFraction: 0.85).delay(0.15)) { shown = value } }
        .onChange(of: value) { _, new in withAnimation(.spring(response: 0.8, dampingFraction: 0.85)) { shown = new } }
    }
}

struct ProbabilityBar: View {
    let disease: Disease
    let probability: Double
    var emphasized = false
    var delay: Double = 0
    @State private var shown: Double = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: disease.symbol).font(.system(size: 11)).foregroundStyle(disease.color)
                Text(disease.name).font(.system(size: 14, weight: emphasized ? .semibold : .regular))
                    .foregroundStyle(emphasized ? Theme.textPrimary : Theme.textSecondary)
                Spacer()
                Text(probability, format: .percent.precision(.fractionLength(1)))
                    .font(.mono(13)).foregroundStyle(emphasized ? Theme.textPrimary : Theme.textTertiary)
                    .contentTransition(.numericText())
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.parchment.opacity(0.07))
                    Capsule()
                        .fill(LinearGradient(colors: [disease.color.opacity(0.65), disease.color], startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(4, geo.size.width * shown))
                        .shadow(color: disease.color.opacity(emphasized ? 0.6 : 0), radius: 6)
                }
            }
            .frame(height: 7)
        }
        .onAppear { withAnimation(.spring(response: 0.9, dampingFraction: 0.85).delay(delay)) { shown = probability } }
        .onChange(of: probability) { _, new in withAnimation(.snappy) { shown = new } }
    }
}

struct InitialsAvatar: View {
    let name: String
    var hue: Double
    var size: CGFloat = 40

    var body: some View {
        let initials = name.split(separator: " ").prefix(2).compactMap { $0.first }.map { String($0) }.joined()
        Text(initials)
            .font(.rounded(size * 0.38, weight: .bold))
            .foregroundStyle(.white.opacity(0.92))
            .frame(width: size, height: size)
            .background(
                Circle().fill(LinearGradient(colors: [Color(hue: hue, saturation: 0.45, brightness: 0.62),
                                                      Color(hue: hue + 0.06, saturation: 0.6, brightness: 0.38)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
            )
            .overlay(Circle().strokeBorder(.white.opacity(0.15), lineWidth: 1))
    }
}

struct IconTile: View {
    let symbol: String
    var color: Color = Theme.rust
    var size: CGFloat = 38

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.42, weight: .semibold))
            .foregroundStyle(color.mix(with: .white, by: 0.2))
            .frame(width: size, height: size)
            .background(RoundedRectangle(cornerRadius: size * 0.32, style: .continuous).fill(color.opacity(0.18)))
            .overlay(RoundedRectangle(cornerRadius: size * 0.32, style: .continuous).strokeBorder(color.opacity(0.3), lineWidth: 0.7))
    }
}

struct StatBlock: View {
    let value: String
    let label: String
    var color: Color = Theme.textPrimary

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value).font(.display(26)).foregroundStyle(color).contentTransition(.numericText())
            Text(label).font(.system(size: 12)).foregroundStyle(Theme.textTertiary)
        }
    }
}

struct EmptyStateView: View {
    let symbol: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: symbol).font(.system(size: 34, weight: .light)).foregroundStyle(Theme.sage)
                .symbolEffect(.pulse, options: .repeating)
            Text(title).font(.display(20)).foregroundStyle(Theme.textPrimary)
            Text(message).font(.system(size: 14)).foregroundStyle(Theme.textSecondary).multilineTextAlignment(.center)
        }
        .padding(30)
        .frame(maxWidth: .infinity)
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    var color: LinearGradient = Theme.rustGradient

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.vertical, 15)
            .frame(maxWidth: .infinity)
            .background(Capsule().fill(color))
            .overlay(Capsule().strokeBorder(.white.opacity(0.18), lineWidth: 1))
            .shadow(color: Theme.rust.opacity(configuration.isPressed ? 0.2 : 0.45), radius: 14, y: 6)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.snappy(duration: 0.2), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(Theme.textPrimary)
            .padding(.vertical, 15)
            .frame(maxWidth: .infinity)
            .background(Capsule().fill(Theme.parchment.opacity(configuration.isPressed ? 0.12 : 0.07)))
            .overlay(Capsule().strokeBorder(Theme.parchment.opacity(0.14), lineWidth: 1))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.snappy(duration: 0.2), value: configuration.isPressed)
    }
}

/// Subtle press-down scale for tappable cards.
struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.975 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.snappy(duration: 0.18), value: configuration.isPressed)
    }
}

extension View {
    /// Leaves room for the floating tab bar at the bottom of scrolling screens.
    func tabBarSafeArea() -> some View {
        safeAreaInset(edge: .bottom) { Color.clear.frame(height: 86) }
    }

    /// A fade behind the status bar for screens that hide the navigation bar, so scrolled
    /// content never runs under the clock.
    func statusBarScrim() -> some View {
        // A zero-height inset at the top of the safe area: its background fills the status bar
        // region exactly, and a short gradient hangs below it so content fades rather than cuts.
        safeAreaInset(edge: .top, spacing: 0) {
            Color.clear
                .frame(height: 0)
                .background(Theme.canopy950.opacity(0.96))
                .overlay(alignment: .top) {
                    LinearGradient(colors: [Theme.canopy950.opacity(0.96), Theme.canopy950.opacity(0)], startPoint: .top, endPoint: .bottom)
                        .frame(height: 22)
                        .allowsHitTesting(false)
                }
        }
    }

    func screenBackground() -> some View {
        background(AppBackground())
            .scrollContentBackground(.hidden)
    }
}

extension Date {
    var relativeShort: String {
        let s = Date.now.timeIntervalSince(self)
        if s < 60 { return "now" }
        if s < 3600 { return "\(Int(s / 60))m" }
        if s < 86_400 { return "\(Int(s / 3600))h" }
        if s < 86_400 * 30 { return "\(Int(s / 86_400))d" }
        return formatted(.dateTime.month(.abbreviated).day())
    }
}
