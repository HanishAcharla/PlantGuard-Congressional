import Foundation

/// Season-by-season view of orchard health derived from scan records. A tree's status in a season
/// is the diagnosis of its most recent scan in that season.
struct OrchardAnalytics {
    let seasons: [Season]
    private let status: [Season: [String: Disease]]
    private let blockOf: [String: String]
    let treeCount: Int

    init(trees: [Tree], scans: [Scan]) {
        var byCode: [String: String] = [:]
        for t in trees { byCode[t.code] = t.block?.letter ?? String(t.code.prefix(1)) }
        blockOf = byCode
        treeCount = trees.count

        var latest: [Season: [String: (Date, Disease)]] = [:]
        for scan in scans {
            guard let code = scan.tree?.code else { continue }
            let s = scan.season
            if let existing = latest[s]?[code], existing.0 > scan.date { continue }
            latest[s, default: [:]][code] = (scan.date, scan.disease)
        }
        status = latest.mapValues { season in season.mapValues { $0.1 } }
        let present = Set(status.keys)
        if let first = present.min(), let last = present.max() {
            seasons = Season.growing(from: first, through: last)
        } else {
            seasons = []
        }
    }

    var latestSeason: Season? { seasons.last }

    func status(of code: String, in season: Season) -> Disease? { status[season]?[code] }

    /// Most recent known status, looking back up to `lookback` seasons.
    func currentStatus(of code: String, lookback: Int = 2) -> Disease? {
        for s in seasons.suffix(lookback).reversed() {
            if let d = status[s]?[code] { return d }
        }
        return nil
    }

    func scannedCount(in season: Season) -> Int { status[season]?.count ?? 0 }

    func infectedCount(in season: Season) -> Int { status[season]?.values.filter(\.isDisease).count ?? 0 }

    func infectionRate(in season: Season) -> Double {
        let n = scannedCount(in: season)
        return n == 0 ? 0 : Double(infectedCount(in: season)) / Double(n)
    }

    func prevalence(in season: Season) -> [Disease: Int] {
        var out: [Disease: Int] = [:]
        for d in (status[season] ?? [:]).values { out[d, default: 0] += 1 }
        return out
    }

    func blockRate(_ letter: String, in season: Season) -> Double? {
        let entries = (status[season] ?? [:]).filter { blockOf[$0.key] == letter }
        guard !entries.isEmpty else { return nil }
        return Double(entries.values.filter(\.isDisease).count) / Double(entries.count)
    }

    /// Ordered statuses for one tree across every season (nil = not scanned that season).
    func timeline(of code: String) -> [(season: Season, disease: Disease?)] {
        seasons.map { ($0, status[$0]?[code]) }
    }

    /// Seasons in which the tree was diagnosed with a disease.
    func infectedSeasons(of code: String) -> Int {
        seasons.filter { status[$0]?[code]?.isDisease == true }.count
    }

    /// Consecutive scanned seasons with disease, counting back from the latest scanned season.
    func streak(of code: String) -> Int {
        var n = 0
        for s in seasons.reversed() {
            guard let d = status[s]?[code] else { continue }
            if d.isDisease { n += 1 } else { break }
        }
        return n
    }

    struct ChronicTree: Identifiable {
        let code: String
        let infectedSeasons: Int
        let streak: Int
        let dominant: Disease
        var id: String { code }
    }

    func chronicTrees(minimumSeasons: Int = 3) -> [ChronicTree] {
        blockOf.keys.compactMap { code -> ChronicTree? in
            let diseases = seasons.compactMap { status[$0]?[code] }.filter(\.isDisease)
            guard diseases.count >= minimumSeasons else { return nil }
            let dominant = Dictionary(grouping: diseases, by: { $0 }).max { $0.value.count < $1.value.count }!.key
            return ChronicTree(code: code, infectedSeasons: diseases.count, streak: streak(of: code), dominant: dominant)
        }
        .sorted { ($0.infectedSeasons, $0.streak) > ($1.infectedSeasons, $1.streak) }
    }

    struct Transitions {
        var stayedHealthy = 0, newlyInfected = 0, recovered = 0, stayedInfected = 0
        var total: Int { stayedHealthy + newlyInfected + recovered + stayedInfected }
    }

    /// How trees scanned in both seasons moved between healthy and infected.
    func transitions(from a: Season, to b: Season) -> Transitions {
        var t = Transitions()
        for (code, now) in status[b] ?? [:] {
            guard let before = status[a]?[code] else { continue }
            switch (before.isDisease, now.isDisease) {
            case (false, false): t.stayedHealthy += 1
            case (false, true): t.newlyInfected += 1
            case (true, false): t.recovered += 1
            case (true, true): t.stayedInfected += 1
            }
        }
        return t
    }

    /// Share of each disease's detections that fell in each season kind — when it peaks.
    func seasonality(of d: Disease) -> [SeasonKind: Double] {
        var counts: [SeasonKind: Int] = [:]
        for s in seasons {
            counts[s.kind, default: 0] += status[s]?.values.filter { $0 == d }.count ?? 0
        }
        let total = Double(counts.values.reduce(0, +))
        return total == 0 ? [:] : counts.mapValues { Double($0) / total }
    }
}
