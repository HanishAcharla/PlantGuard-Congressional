import Foundation

/// Apple-orchard seasons. Winter (Dec–Feb) is dormant — no leaves to scan — so tracking uses the
/// three growing seasons.
enum SeasonKind: Int, Codable, CaseIterable, Comparable {
    case winter = 0, spring, summer, fall

    static func < (a: SeasonKind, b: SeasonKind) -> Bool { a.rawValue < b.rawValue }

    var name: String {
        switch self {
        case .winter: "Winter"
        case .spring: "Spring"
        case .summer: "Summer"
        case .fall: "Fall"
        }
    }

    var symbol: String {
        switch self {
        case .winter: "snowflake"
        case .spring: "camera.macro"
        case .summer: "sun.max.fill"
        case .fall: "leaf.fill"
        }
    }

    /// Calendar months (1–12) belonging to this season. December belongs to the following year's winter.
    var months: [Int] {
        switch self {
        case .winter: [12, 1, 2]
        case .spring: [3, 4, 5]
        case .summer: [6, 7, 8]
        case .fall: [9, 10, 11]
        }
    }
}

struct Season: Hashable, Comparable, Identifiable, Codable {
    let year: Int
    let kind: SeasonKind

    var id: Int { index }
    var index: Int { year * 4 + kind.rawValue }

    static func < (a: Season, b: Season) -> Bool { a.index < b.index }

    init(year: Int, kind: SeasonKind) {
        self.year = year
        self.kind = kind
    }

    init(date: Date, calendar: Calendar = .current) {
        let month = calendar.component(.month, from: date)
        let year = calendar.component(.year, from: date)
        switch month {
        case 3...5: self.init(year: year, kind: .spring)
        case 6...8: self.init(year: year, kind: .summer)
        case 9...11: self.init(year: year, kind: .fall)
        case 12: self.init(year: year + 1, kind: .winter)
        default: self.init(year: year, kind: .winter)
        }
    }

    static var current: Season { Season(date: .now) }

    var label: String { "\(kind.name) \(year)" }
    var shortLabel: String { "\(kind.name.prefix(2).uppercased())\u{2019}\(String(year).suffix(2))" }
    var isGrowing: Bool { kind != .winter }

    var next: Season {
        kind == .fall ? Season(year: year + 1, kind: .winter) : Season(year: year, kind: SeasonKind(rawValue: kind.rawValue + 1)!)
    }

    var nextGrowing: Season {
        var s = next
        while !s.isGrowing { s = s.next }
        return s
    }

    var previousGrowing: Season {
        var s = self
        repeat {
            s = s.kind == .winter ? Season(year: s.year - 1, kind: .fall) : Season(year: s.year, kind: SeasonKind(rawValue: s.kind.rawValue - 1)!)
        } while !s.isGrowing
        return s
    }

    /// First and last instant of the season.
    var dateInterval: DateInterval {
        let cal = Calendar.current
        let startMonth = kind.months.first!
        let startYear = kind == .winter ? year - 1 : year
        let start = cal.date(from: DateComponents(year: startYear, month: startMonth, day: 1))!
        let end = cal.date(byAdding: .month, value: 3, to: start)!
        return DateInterval(start: start, end: end)
    }

    /// Growing seasons from `start` through `end`, inclusive.
    static func growing(from start: Season, through end: Season) -> [Season] {
        var out: [Season] = []
        var s = start.isGrowing ? start : start.nextGrowing
        while s <= end {
            out.append(s)
            s = s.nextGrowing
        }
        return out
    }
}
