import SwiftUI

/// The six classes the ResNet-50 was trained on. `modelOrder` must match the Core ML output labels.
enum Disease: String, Codable, CaseIterable, Identifiable, Hashable {
    case complex
    case frogEyeLeafSpot = "frog_eye_leaf_spot"
    case healthy
    case powderyMildew = "powdery_mildew"
    case rust
    case scab

    var id: String { rawValue }

    static let modelOrder: [Disease] = [.complex, .frogEyeLeafSpot, .healthy, .powderyMildew, .rust, .scab]
    static let diseases: [Disease] = [.scab, .rust, .powderyMildew, .frogEyeLeafSpot, .complex]

    var name: String {
        switch self {
        case .complex: "Complex"
        case .frogEyeLeafSpot: "Frog Eye Leaf Spot"
        case .healthy: "Healthy"
        case .powderyMildew: "Powdery Mildew"
        case .rust: "Cedar Apple Rust"
        case .scab: "Apple Scab"
        }
    }

    var shortName: String {
        switch self {
        case .complex: "Complex"
        case .frogEyeLeafSpot: "Frog Eye"
        case .healthy: "Healthy"
        case .powderyMildew: "Mildew"
        case .rust: "Rust"
        case .scab: "Scab"
        }
    }

    var pathogen: String {
        switch self {
        case .complex: "Multiple pathogens"
        case .frogEyeLeafSpot: "Botryosphaeria obtusa"
        case .healthy: "No pathogen detected"
        case .powderyMildew: "Podosphaera leucotricha"
        case .rust: "Gymnosporangium juniperi-virginianae"
        case .scab: "Venturia inaequalis"
        }
    }

    var color: Color {
        switch self {
        case .complex: Color(hex: 0x9B88F2)
        case .frogEyeLeafSpot: Color(hex: 0xD06A9E)
        case .healthy: Color(hex: 0x62C58A)
        case .powderyMildew: Color(hex: 0xA9C3E0)
        case .rust: Color(hex: 0xEE8540)
        case .scab: Color(hex: 0xCDAE3A)
        }
    }

    var symbol: String {
        switch self {
        case .complex: "square.stack.3d.up.fill"
        case .frogEyeLeafSpot: "eye.circle.fill"
        case .healthy: "leaf.fill"
        case .powderyMildew: "cloud.fill"
        case .rust: "flame.fill"
        case .scab: "circle.hexagongrid.fill"
        }
    }

    var isDisease: Bool { self != .healthy }
}

enum ScanSource: String, Codable {
    case camera, library, files, demo

    var label: String {
        switch self {
        case .camera: "Camera"
        case .library: "Photos"
        case .files: "Files"
        case .demo: "Field survey"
        }
    }
}
