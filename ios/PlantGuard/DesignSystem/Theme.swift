import SwiftUI

/// Brand palette shared with the PlantGuard website: deep canopy greens, parchment ink, rust accent.
enum Theme {
    static let canopy950 = Color(hex: 0x07130D)
    static let canopy900 = Color(hex: 0x0C1E16)
    static let canopy850 = Color(hex: 0x10251B)
    static let canopy800 = Color(hex: 0x14301F)
    static let canopy700 = Color(hex: 0x1A3A2A)
    static let canopy500 = Color(hex: 0x2F6B49)
    static let canopy400 = Color(hex: 0x4C8F65)
    static let sage = Color(hex: 0x7FB896)
    static let mint = Color(hex: 0xA8DDB5)

    static let parchment = Color(hex: 0xF8F2E2)
    static let rust = Color(hex: 0xC96A35)
    static let rustLight = Color(hex: 0xEE9A62)
    static let amber = Color(hex: 0xE3B04B)
    static let danger = Color(hex: 0xE0675A)

    static let textPrimary = parchment
    static let textSecondary = parchment.opacity(0.68)
    static let textTertiary = parchment.opacity(0.42)
    static let hairline = parchment.opacity(0.09)
    static let cardFill = Color(hex: 0x10251B).opacity(0.62)

    static let rustGradient = LinearGradient(colors: [rustLight, rust, Color(hex: 0xA8502A)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing)
    static let sageGradient = LinearGradient(colors: [mint, sage, canopy400],
                                             startPoint: .topLeading, endPoint: .bottomTrailing)
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: opacity)
    }
}

extension Font {
    /// Editorial serif used for titles and hero numbers.
    static func display(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }
    static func mono(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
    static func rounded(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

extension View {
    /// Small uppercase tracking label used above section titles ("kicker").
    func kickerStyle(_ color: Color = Theme.rustLight) -> some View {
        self.font(.mono(11, weight: .semibold))
            .textCase(.uppercase)
            .tracking(1.6)
            .foregroundStyle(color)
    }
}

enum Haptics {
    static func tap() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func soft() { UIImpactFeedbackGenerator(style: .soft).impactOccurred() }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func warning() { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
}
