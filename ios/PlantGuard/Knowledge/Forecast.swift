import SwiftUI

struct ClimateProfile: Identifiable, Hashable {
    let id: String
    let name: String
    /// Monthly normals, January first.
    let highs: [Double]
    let lows: [Double]
    let rainChance: [Double]

    static let appleHill = ClimateProfile(
        id: "apple-hill", name: "Apple Hill, CA",
        highs: [52, 55, 59, 64, 73, 82, 90, 89, 83, 73, 59, 52],
        lows: [33, 34, 36, 39, 45, 51, 56, 55, 51, 44, 37, 32],
        rainChance: [0.38, 0.36, 0.33, 0.24, 0.13, 0.05, 0.01, 0.01, 0.05, 0.14, 0.29, 0.36])
    static let wenatchee = ClimateProfile(
        id: "wenatchee", name: "Wenatchee, WA",
        highs: [34, 42, 54, 63, 72, 79, 88, 87, 77, 62, 44, 34],
        lows: [22, 25, 31, 37, 45, 52, 58, 57, 48, 38, 29, 22],
        rainChance: [0.30, 0.24, 0.18, 0.14, 0.14, 0.12, 0.05, 0.05, 0.08, 0.15, 0.27, 0.32])
    static let hudsonValley = ClimateProfile(
        id: "hudson", name: "Hudson Valley, NY",
        highs: [34, 37, 46, 59, 70, 78, 83, 81, 74, 62, 50, 39],
        lows: [17, 19, 27, 37, 47, 56, 61, 60, 52, 40, 32, 23],
        rainChance: [0.33, 0.30, 0.34, 0.37, 0.38, 0.36, 0.33, 0.31, 0.30, 0.30, 0.33, 0.34])

    static let all = [appleHill, wenatchee, hudsonValley]
    static func with(id: String) -> ClimateProfile { all.first { $0.id == id } ?? appleHill }
}

struct WeatherDay: Identifiable, Hashable {
    let date: Date
    let highF: Double
    let lowF: Double
    let rainMM: Double
    let wetHours: Double
    let humidity: Double

    var id: Date { date }
    var meanF: Double { (highF + lowF) / 2 }
    /// Temperature during the wet period — rain usually falls on the cooler part of the day.
    var wetTempF: Double { lowF + (highF - lowF) * (rainMM > 0 ? 0.35 : 0.2) }

    var symbol: String {
        if rainMM > 12 { return "cloud.heavyrain.fill" }
        if rainMM > 0 { return "cloud.rain.fill" }
        if humidity > 78 { return "cloud.fog.fill" }
        if humidity > 62 { return "cloud.sun.fill" }
        return "sun.max.fill"
    }
}

/// Deterministic, offline weather: regional monthly normals plus smooth day-to-day noise so wet and
/// dry spells cluster like real weather. The same date always produces the same day.
enum WeatherSimulator {
    static func day(_ date: Date, climate: ClimateProfile) -> WeatherDay {
        let cal = Calendar.current
        let start = cal.startOfDay(for: date)
        let dayNumber = Int(start.timeIntervalSince1970 / 86_400)
        let month = cal.component(.month, from: start) - 1
        let salt = climate.id.unicodeScalars.reduce(0) { $0 &* 31 &+ Int($1.value) }

        let wetness = smoothNoise(dayNumber, period: 3, salt: salt)
        let warmth = smoothNoise(dayNumber, period: 5, salt: salt &+ 101) - 0.5
        var rng = SeededRandom(dayNumber &* 2_654_435 &+ salt)

        let rainy = wetness < climate.rainChance[month] * 1.15
        let high = climate.highs[month] + warmth * 14 - (rainy ? 6 : 0) + rng.range(-2...2)
        let low = min(high - 6, climate.lows[month] + warmth * 9 + rng.range(-2...2))
        let rain = rainy ? rng.range(1.5...22) * (1.2 - wetness) : 0
        let humidity = rainy ? rng.range(84...98) : max(30, min(92, 78 - (high - 60) * 0.7 + rng.range(-10...12)))
        let wet: Double = rainy ? min(24, 4 + rain * 0.7 + rng.range(0...6)) : (humidity > 80 ? rng.range(2...6) : rng.range(0...2))
        return WeatherDay(date: start, highF: high.rounded(), lowF: low.rounded(), rainMM: (rain * 10).rounded() / 10,
                          wetHours: wet.rounded(), humidity: humidity.rounded())
    }

    static func days(around date: Date = .now, past: Int = 2, future: Int = 9, climate: ClimateProfile) -> [WeatherDay] {
        (-past...future).compactMap { Calendar.current.date(byAdding: .day, value: $0, to: date) }.map { day($0, climate: climate) }
    }

    /// Value noise in 0…1 interpolated between random knots every `period` days.
    private static func smoothNoise(_ day: Int, period: Int, salt: Int) -> Double {
        let k0 = Int((Double(day) / Double(period)).rounded(.down))
        let t = Double(day - k0 * period) / Double(period)
        var a = SeededRandom(k0 &* 92_821 &+ salt), b = SeededRandom((k0 + 1) &* 92_821 &+ salt)
        let s = t * t * (3 - 2 * t)
        return a.unit() * (1 - s) + b.unit() * s
    }
}

enum RiskLevel: Int, Comparable {
    case low, moderate, high
    static func < (a: RiskLevel, b: RiskLevel) -> Bool { a.rawValue < b.rawValue }

    init(score: Double) { self = score < 0.3 ? .low : score < 0.65 ? .moderate : .high }

    var label: String {
        switch self {
        case .low: "Low"
        case .moderate: "Moderate"
        case .high: "High"
        }
    }
    var color: Color {
        switch self {
        case .low: Theme.sage
        case .moderate: Theme.amber
        case .high: Theme.danger
        }
    }
}

struct DiseaseRisk: Identifiable {
    let disease: Disease
    let score: Double
    let reason: String
    var id: Disease { disease }
    var level: RiskLevel { RiskLevel(score: score) }
}

/// Weather-driven infection risk. Scab uses the (approximate) Mills table of wetting hours needed
/// for infection at a given temperature; the others use the conditions each pathogen favours.
/// Every score is scaled by how susceptible the orchard is at that time of year.
enum RiskModel {
    /// (°F, hours of leaf wetness for a light scab infection) — Mills (1944), approximate.
    private static let mills: [(Double, Double)] = [
        (33, 48), (37, 41), (40, 35), (42, 30), (43, 25), (44, 22), (45, 20), (46, 19), (47, 17), (48, 15),
        (50, 14), (52, 12), (54, 11.5), (56, 11), (58, 10), (60, 9.5), (62, 9), (75, 9), (76, 9.5), (77, 11), (78, 13),
    ]

    static func millsHours(atF t: Double) -> Double? {
        guard t >= mills.first!.0, t <= mills.last!.0 else { return nil }
        for (a, b) in zip(mills, mills.dropFirst()) where t >= a.0 && t <= b.0 {
            let f = (t - a.0) / (b.0 - a.0)
            return a.1 + (b.1 - a.1) * f
        }
        return nil
    }

    // Seasonal susceptibility, January first.
    private static let scabPhase = [0.05, 0.1, 0.8, 1, 1, 0.7, 0.35, 0.3, 0.4, 0.4, 0.15, 0.05]
    private static let rustPhase = [0.0, 0, 0.3, 1, 1, 0.6, 0.2, 0.1, 0, 0, 0, 0]
    private static let mildewPhase = [0.0, 0, 0.3, 0.9, 1, 1, 0.8, 0.6, 0.3, 0.1, 0, 0]
    private static let frogEyePhase = [0.0, 0, 0.1, 0.4, 0.8, 1, 1, 1, 0.8, 0.45, 0.1, 0]

    static func risks(for day: WeatherDay) -> [DiseaseRisk] {
        let m = Calendar.current.component(.month, from: day.date) - 1
        var out: [DiseaseRisk] = []

        // Apple scab — Mills table.
        if day.wetHours > 0, let needed = millsHours(atF: day.wetTempF) {
            let env = min(1.4, day.wetHours / needed)
            let reason = env >= 1
                ? "\(Int(day.wetHours)) h wet at \(Int(day.wetTempF))°F — enough for infection (Mills: \(Int(needed.rounded())) h)"
                : "\(Int(day.wetHours)) h wet at \(Int(day.wetTempF))°F — below the \(Int(needed.rounded())) h infection threshold"
            out.append(DiseaseRisk(disease: .scab, score: min(1, (env >= 1 ? 0.55 + 0.45 * min(1, env - 0.6) : env * 0.45) * scabPhase[m]), reason: reason))
        } else {
            out.append(DiseaseRisk(disease: .scab, score: 0.02, reason: "Leaves stay dry or it's too cold for infection"))
        }

        // Cedar apple rust — spring rain at mild temperatures.
        let rustEnv = (day.rainMM > 0 && (50...75).contains(day.meanF) && day.wetHours >= 4) ? min(1, day.wetHours / 8) : 0.05
        out.append(DiseaseRisk(disease: .rust, score: rustEnv * rustPhase[m],
                               reason: rustEnv > 0.1 ? "Rain at \(Int(day.meanF))°F with \(Int(day.wetHours)) h wetness — galls release spores" : "No spore-releasing rain"))

        // Powdery mildew — warm, humid, and dry.
        let mildewEnv = (day.rainMM < 1 && (62...84).contains(day.meanF) && day.humidity >= 60) ? min(1, (day.humidity - 50) / 40) : 0.08
        out.append(DiseaseRisk(disease: .powderyMildew, score: mildewEnv * mildewPhase[m],
                               reason: mildewEnv > 0.2 ? "Warm (\(Int(day.meanF))°F) and humid (\(Int(day.humidity))%) without rain" : "Too cool, dry or rainy for mildew"))

        // Frog eye / black rot — warm and wet.
        let frogEnv = (day.meanF >= 66 && day.wetHours >= 6) ? min(1, day.wetHours / 12) : 0.05
        out.append(DiseaseRisk(disease: .frogEyeLeafSpot, score: frogEnv * frogEyePhase[m],
                               reason: frogEnv > 0.1 ? "\(Int(day.wetHours)) h wet at \(Int(day.meanF))°F favours spore splash" : "Not warm and wet enough"))
        return out.sorted { $0.score > $1.score }
    }
}
