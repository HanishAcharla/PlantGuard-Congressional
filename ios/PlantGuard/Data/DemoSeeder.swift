import Foundation
import SwiftData

/// Builds the demo orchard and simulates nine seasons of field surveys with a simple spatial
/// epidemic model, so cross-season tracking, the map and the analytics have realistic patterns
/// to show: infections spread to neighbours, scab and mildew overwinter on the same trees, rust
/// clusters near the cedar windbreak, 2025 is a wet outbreak year, and 2026's spray programs work.
enum DemoSeeder {
    static let anchorLatitude = 38.73572
    static let anchorLongitude = -120.67018
    static let rowSpacing = 4.0
    static let treeSpacing = 2.8
    /// Eastern red cedar windbreak along the east fence — the rust source (local x, metres).
    static let windbreakX = 64.0

    struct BlockSpec {
        let name, letter, variety: String
        let planted, rows, perRow: Int
        let originX, originY: Double
    }

    static let blockSpecs = [
        BlockSpec(name: "North Ridge", letter: "A", variety: "Honeycrisp", planted: 2014, rows: 6, perRow: 12, originX: 0, originY: 42),
        BlockSpec(name: "Creekside", letter: "B", variety: "Gala", planted: 2011, rows: 6, perRow: 12, originX: 34, originY: 42),
        BlockSpec(name: "Old Barn", letter: "C", variety: "Fuji", planted: 2008, rows: 6, perRow: 10, originX: 0, originY: 0),
        BlockSpec(name: "South Slope", letter: "D", variety: "Granny Smith", planted: 2017, rows: 5, perRow: 10, originX: 34, originY: 0),
    ]

    @MainActor
    static func reset(_ context: ModelContext, withHistory: Bool) throws {
        try context.delete(model: NoteComment.self)
        try context.delete(model: CommunityNote.self)
        try context.delete(model: Scan.self)
        try context.delete(model: TreatmentRecord.self)
        try context.delete(model: Tree.self)
        try context.delete(model: OrchardBlock.self)
        try context.delete(model: Orchard.self)
        try context.save()

        let orchard = Orchard(name: "Hillcrest Orchard", region: "Apple Hill · Camino, CA",
                              anchorLatitude: anchorLatitude, anchorLongitude: anchorLongitude, headingDegrees: 12)
        context.insert(orchard)

        var trees: [Tree] = []
        for spec in blockSpecs {
            let block = OrchardBlock(name: spec.name, letter: spec.letter, variety: spec.variety, plantedYear: spec.planted,
                                     rows: spec.rows, treesPerRow: spec.perRow, rowSpacing: rowSpacing, treeSpacing: treeSpacing,
                                     originX: spec.originX, originY: spec.originY)
            context.insert(block)
            block.orchard = orchard
            for r in 0..<spec.rows {
                for p in 0..<spec.perRow {
                    let x = spec.originX + (Double(r) + 0.5) * rowSpacing
                    let y = spec.originY + (Double(p) + 0.5) * treeSpacing
                    let c = OrchardGeometry.coordinate(x: x, y: y, in: orchard)
                    let tree = Tree(code: String(format: "%@-%02d-%02d", spec.letter, r + 1, p + 1), row: r + 1, position: p + 1,
                                    variety: spec.variety, plantedYear: spec.planted, localX: x, localY: y,
                                    latitude: c.latitude, longitude: c.longitude)
                    context.insert(tree)
                    tree.block = block
                    trees.append(tree)
                }
            }
        }

        if withHistory {
            simulateHistory(trees: trees, context: context)
            seedCommunity(context)
        }
        try context.save()
    }

    // MARK: - Epidemic simulation

    private static let tracked: [Disease] = [.scab, .rust, .powderyMildew, .frogEyeLeafSpot]

    private static func baseRate(_ d: Disease, _ k: SeasonKind) -> Double {
        let table: [SeasonKind: [Disease: Double]] = [
            .spring: [.scab: 0.060, .rust: 0.032, .powderyMildew: 0.026, .frogEyeLeafSpot: 0.012],
            .summer: [.scab: 0.034, .rust: 0.030, .powderyMildew: 0.052, .frogEyeLeafSpot: 0.044],
            .fall: [.scab: 0.038, .rust: 0.012, .powderyMildew: 0.020, .frogEyeLeafSpot: 0.034],
        ]
        return table[k]?[d] ?? 0
    }

    private static func susceptibility(_ d: Disease, _ variety: String) -> Double {
        let table: [String: [Disease: Double]] = [
            "Honeycrisp": [.scab: 0.9, .rust: 0.7, .powderyMildew: 1.0, .frogEyeLeafSpot: 1.2],
            "Gala": [.scab: 1.35, .rust: 1.4, .powderyMildew: 1.15, .frogEyeLeafSpot: 1.0],
            "Fuji": [.scab: 1.3, .rust: 1.2, .powderyMildew: 1.0, .frogEyeLeafSpot: 1.0],
            "Granny Smith": [.scab: 1.1, .rust: 0.6, .powderyMildew: 1.7, .frogEyeLeafSpot: 0.9],
        ]
        return table[variety]?[d] ?? 1
    }

    private static func persistence(_ d: Disease) -> Double {
        switch d {
        case .scab: 0.24
        case .powderyMildew: 0.30
        case .frogEyeLeafSpot: 0.18
        default: 0.08
        }
    }

    /// Year 3's management programs: scab programs in A and B, a rust program in B and D.
    private static func programFactor(block: String, yearIndex: Int, disease: Disease) -> Double {
        guard yearIndex >= 2 else { return 1 }
        switch (block, disease) {
        case ("A", .scab), ("B", .scab): return 0.45
        case ("B", .rust), ("D", .rust): return 0.5
        case ("D", .powderyMildew): return 0.6
        default: return 1
        }
    }

    private static func carries(_ status: Disease, _ d: Disease) -> Bool {
        status == d || (status == .complex && (d == .scab || d == .frogEyeLeafSpot))
    }

    private static func simulateHistory(trees: [Tree], context: ModelContext) {
        var rng = SeededRandom(seed: 20_240_401)
        let end = Season.current
        var start = end
        for _ in 0..<8 { start = start.previousGrowing }
        let seasons = Season.growing(from: start, through: end)
        let yearFactors = [1.0, 1.3, 0.8]
        let now = Date.now

        // Snapshot model properties into plain arrays — reading SwiftData attributes inside the
        // O(n²) neighbour search and the per-season loops is what made seeding slow.
        let n = trees.count
        let xs = trees.map(\.localX), ys = trees.map(\.localY)
        let varieties = trees.map(\.variety)
        let blockLetters = trees.map { $0.block?.letter ?? "A" }
        var neighbours = [[Int]](repeating: [], count: n)
        for i in 0..<n {
            for j in 0..<n where i != j && hypot(xs[i] - xs[j], ys[i] - ys[j]) < 6.5 {
                neighbours[i].append(j)
            }
        }

        var truth = [Disease](repeating: .healthy, count: n)
        var infectedSeasons = [Int](repeating: 0, count: n)

        for (k, season) in seasons.enumerated() {
            let yearIndex = min(season.year - start.year, 2)
            let yearFactor = yearFactors[max(0, yearIndex)]
            var next = truth
            for i in 0..<n {
                let block = blockLetters[i]
                var found: [Disease] = []
                for d in tracked {
                    var p = baseRate(d, season.kind) * susceptibility(d, varieties[i]) * yearFactor
                    if d == .rust { p *= 1 + 2.4 * exp(-(windbreakX - xs[i]) / 11) }
                    let near = neighbours[i]
                    if !near.isEmpty {
                        p += 0.15 * Double(near.filter { carries(truth[$0], d) }.count) / Double(near.count)
                    }
                    if k > 0 && carries(truth[i], d) { p += persistence(d) }
                    p *= programFactor(block: block, yearIndex: yearIndex, disease: d)
                    if rng.chance(min(0.8, p)) { found.append(d) }
                }
                next[i] = found.isEmpty ? .healthy : found.count >= 2 ? .complex : found[0]
            }
            let previous = truth
            truth = next

            // Field surveys: suspicious and previously infected trees get scanned more often.
            let interval = season.dateInterval
            guard interval.start < now else { break }
            let surveyEnd = min(interval.end, now.addingTimeInterval(-6 * 3600))
            let partial = surveyEnd < interval.end ? max(0.4, surveyEnd.timeIntervalSince(interval.start) / interval.duration) : 1
            for i in 0..<n {
                var pScan = 0.3 + (k > 0 && previous[i].isDisease ? 0.3 : 0) + (truth[i].isDisease ? 0.12 : 0)
                pScan *= partial
                guard rng.chance(pScan) else { continue }
                let day = interval.start.addingTimeInterval(rng.range(0...max(3600, surveyEnd.timeIntervalSince(interval.start) - 86_400)))
                let date = Calendar.current.startOfDay(for: day).addingTimeInterval(rng.range(8...17.5) * 3600)
                let scan = Scan(date: date, probabilities: predicted(from: truth[i], rng: &rng), source: .demo,
                                notes: surveyNote(&rng), artSeed: rng.int(0...999_999), inferenceMilliseconds: rng.range(14...38))
                context.insert(scan)
                scan.tree = trees[i]
            }
            for i in 0..<n where truth[i].isDisease { infectedSeasons[i] += 1 }
            seedBlockTreatments(season: season, truth: truth, blockLetters: blockLetters, context: context, rng: &rng)
        }

        // Flag the worst repeat offenders and record the extra work done on them.
        let chronic = (0..<n).filter { infectedSeasons[$0] >= 4 }.sorted { infectedSeasons[$0] > infectedSeasons[$1] }.prefix(8)
        for i in chronic {
            let tree = trees[i]
            tree.isFlagged = true
            tree.notes = "Repeat infections \(infectedSeasons[i]) of \(seasons.count) seasons. Check for cankers and leaf litter build-up under the canopy."
            let winter = Calendar.current.date(from: DateComponents(year: end.year, month: 2, day: rng.int(3...24)))!
            if winter < now {
                let t = TreatmentRecord(title: "Pruned out cankers and infected shoots", disease: truth[i].isDisease ? truth[i] : .scab,
                                        category: .cultural, scheduledDate: winter, status: .applied, notes: "Dormant pruning, chronic tree.")
                context.insert(t)
                t.tree = tree
            }
        }

        // Upcoming work, always relative to today.
        let planned: [(Int, String, Disease, TreatmentCategory, String?, String)] = [
            (5, "Apply 5% urea to leaf litter", .scab, .cultural, "Block B", "After harvest, before leaf drop finishes."),
            (12, "Shred leaf litter in row middles", .scab, .cultural, "Blocks A & B", "Rake leaves out from under the tree row first."),
            (40, "Remove mummified fruit", .frogEyeLeafSpot, .cultural, "Block C", "Ground and canopy."),
            (125, "Dormant pruning — cut mildew flag shoots", .powderyMildew, .cultural, "Block D", "Silvery, stunted shoots."),
            (160, "Copper at green tip", .scab, .organic, nil, "Switch products by tight cluster."),
        ]
        for (days, title, disease, category, block, note) in planned {
            let date = Calendar.current.date(byAdding: .day, value: days, to: Calendar.current.startOfDay(for: now))!.addingTimeInterval(8 * 3600)
            context.insert(TreatmentRecord(title: title, disease: disease, category: category, scheduledDate: date, notes: note, blockName: block))
        }
    }

    private static func seedBlockTreatments(season: Season, truth: [Disease], blockLetters: [String], context: ModelContext, rng: inout SeededRandom) {
        let interval = season.dateInterval
        for spec in blockSpecs {
            let idx = blockLetters.indices.filter { blockLetters[$0] == spec.letter }
            var counts: [Disease: Int] = [:]
            for i in idx { for d in tracked where carries(truth[i], d) { counts[d, default: 0] += 1 } }
            let pressing = counts.filter { Double($0.value) / Double(idx.count) > 0.1 }.sorted { $0.value > $1.value }.prefix(2)
            for (d, _) in pressing {
                let (title, category, note) = programStep(d, season.kind)
                let date = interval.start.addingTimeInterval(interval.duration * rng.range(0.3...0.7))
                guard date < .now else { continue }
                context.insert(TreatmentRecord(title: title, disease: d, category: category, scheduledDate: date, status: .applied,
                                               notes: note, blockName: "Block \(spec.letter)"))
            }
        }
    }

    private static func programStep(_ d: Disease, _ k: SeasonKind) -> (String, TreatmentCategory, String) {
        switch (d, k) {
        case (.scab, .spring): ("Captan + difenoconazole cover", .conventional, "Applied ahead of a forecast infection period.")
        case (.scab, .summer): ("Captan cover spray", .conventional, "Secondary scab after wet spell.")
        case (.scab, _): ("Shredded leaf litter + 5% urea", .cultural, "Post-harvest sanitation.")
        case (.rust, .spring): ("Myclobutanil at pink", .conventional, "Cedar galls active after rain.")
        case (.rust, .summer): ("Mancozeb protectant", .conventional, "Late spore release near windbreak.")
        case (.rust, _): ("Scouted windbreak for cedar galls", .monitoring, "Marked galls for winter removal.")
        case (.powderyMildew, .spring): ("Sulfur, 7-day interval", .organic, "Tight cluster through bloom.")
        case (.powderyMildew, .summer): ("Sulfur + potassium bicarbonate", .organic, "Knocked back active colonies.")
        case (.powderyMildew, _): ("Flagged mildew shoots for pruning", .cultural, "Tape on silvery shoots.")
        case (.frogEyeLeafSpot, .summer): ("Captan cover spray", .conventional, "Warm, wet week after hail.")
        case (.frogEyeLeafSpot, _): ("Removed dead wood and mummies", .cultural, "Spore sources out of the canopy.")
        default: ("Scouting round", .monitoring, "")
        }
    }

    private static func confusable(_ d: Disease) -> [Disease] {
        switch d {
        case .healthy: [.scab, .powderyMildew, .frogEyeLeafSpot]
        case .scab: [.complex, .frogEyeLeafSpot, .healthy]
        case .rust: [.complex, .frogEyeLeafSpot, .scab]
        case .powderyMildew: [.healthy, .complex, .scab]
        case .frogEyeLeafSpot: [.complex, .scab, .rust]
        case .complex: [.scab, .frogEyeLeafSpot, .rust]
        }
    }

    /// A plausible model output for a leaf whose true condition is `truth` — mostly right, sometimes
    /// confused with the classes the paper's confusion matrix shows it mixes up.
    private static func predicted(from truth: Disease, rng: inout SeededRandom) -> [Double] {
        let accuracy = truth == .healthy ? 0.93 : truth == .complex ? 0.7 : 0.87
        let mix = confusable(truth)
        let label = rng.chance(accuracy) ? truth : mix[rng.int(0...mix.count - 1)]
        let top = label == truth ? rng.range(0.66...0.99) : rng.range(0.46...0.8)
        var probs = [Double](repeating: 0, count: 6)
        let iTop = Disease.modelOrder.firstIndex(of: label)!
        probs[iTop] = top
        let runnerUp = label == truth ? mix[0] : truth
        let iSecond = Disease.modelOrder.firstIndex(of: runnerUp)!
        var remaining = 1 - top
        let share = remaining * rng.range(0.55...0.85)
        probs[iSecond] += share
        remaining -= share
        let rest = (0..<6).filter { $0 != iTop && $0 != iSecond }
        let weights = rest.map { _ in rng.range(0.05...1) }
        let sum = weights.reduce(0, +)
        for (j, w) in zip(rest, weights) { probs[j] += remaining * w / sum }
        return probs
    }

    private static func surveyNote(_ rng: inout SeededRandom) -> String {
        let notes = ["Lower canopy, north side", "After two days of rain", "Re-check of last visit's spots", "Leaf from a terminal shoot",
                     "Sun-side leaf", "Spotted during thinning", "Near the row end"]
        return rng.chance(0.3) ? notes[rng.int(0...notes.count - 1)] : ""
    }

    // MARK: - Community

    private static func seedCommunity(_ context: ModelContext) {
        struct Post {
            let author, role, region: String
            let hue: Double
            let title, body: String
            let disease: Disease?
            let tags: [String]
            let daysAgo: Double
            let upvotes: Int
            let comments: [(String, String)]
        }
        let posts: [Post] = [
            Post(author: "Jordan Pike", role: "New grower", region: "Hood River, OR", hue: 0.58,
                 title: "Scanner keeps saying \u{201C}Complex\u{201D} — treat for everything?",
                 body: "Got Complex at around 70% on three leaves from the same tree. Do I need to spray for every disease at once, or is there a smarter way to figure out what's going on?",
                 disease: .complex, tags: ["question", "model"], daysAgo: 0.6, upvotes: 12,
                 comments: [("Priya Natarajan", "Complex means more than one disease on the leaf. Look closely — it's often scab plus frog eye. A broad protectant like captan covers both while you confirm."),
                            ("Maria Delgado", "Scan a few more leaves from different sides of the tree. If they split between scab and frog eye, that's your answer.")]),
            Post(author: "Dale Henshaw", role: "Orchard manager", region: "Wenatchee, WA", hue: 0.08,
                 title: "Shred the leaf litter before anything else this fall",
                 body: "We flail-mowed every row middle after leaf drop last year and sprayed 5% urea on what was left. Primary scab this spring was the lowest we've had in six seasons. Cheapest scab control we've ever done.",
                 disease: .scab, tags: ["sanitation", "fall"], daysAgo: 2, upvotes: 48,
                 comments: [("Priya Natarajan", "Did you rake the leaves out from under the tree row first? That's where most of them collect."),
                            ("Dale Henshaw", "Yes — side-delivery rake into the middle, then mow. Two passes.")]),
            Post(author: "Ana Ruiz", role: "Family orchard", region: "Apple Hill, CA", hue: 0.02,
                 title: "Rust on the Gala again — it's the cedar windbreak",
                 body: "Every tree within about 50 m of our eastern red cedar row lights up orange by June. Trees on the far side barely get it. Pulling the cedars this winter and replacing the windbreak with something that isn't a rust host.",
                 disease: .rust, tags: ["junipers", "gala"], daysAgo: 4, upvotes: 31,
                 comments: [("Tom Becker", "Same here. Check the neighbours' property too — spores travel a long way."),
                            ("Kwame Osei", "Removing cedars within a few hundred yards helps a lot. Galls are easiest to spot in late winter, then they turn into orange horns after spring rain.")]),
            Post(author: "Priya Natarajan", role: "Extension agent", region: "Yakima, WA", hue: 0.75,
                 title: "Mark mildew flag shoots now, prune them in winter",
                 body: "Silvery, stunted shoots are where powdery mildew overwinters — inside the buds. Flag them with tape while they're easy to see this fall, then cut them out during dormant pruning. Granny Smith and Jonathan are the worst for it.",
                 disease: .powderyMildew, tags: ["pruning", "granny smith"], daysAgo: 6, upvotes: 57, comments: []),
            Post(author: "Tom Becker", role: "Commercial grower", region: "Grand Rapids, MI", hue: 0.33,
                 title: "Frog eye showed up two weeks after the hail",
                 body: "Purple-ringed spots all over one block after August hail — the broken wood was the spore source. Pruned out every damaged limb and pulled the mummies, and new spotting stopped within a month.",
                 disease: .frogEyeLeafSpot, tags: ["hail", "sanitation"], daysAgo: 9, upvotes: 26,
                 comments: [("Ellen Fairweather", "Good reminder to check for cankers after any storm, not just hail.")]),
            Post(author: "Maria Delgado", role: "Commercial grower", region: "Wenatchee, WA", hue: 0.92,
                 title: "Tip: scan the underside for mildew",
                 body: "Mildew starts on the lower leaf surface. When I flip the leaf over and fill the frame, the scanner's confidence jumps from around 60% to over 90%.",
                 disease: .powderyMildew, tags: ["tip", "scanning"], daysAgo: 12, upvotes: 39, comments: []),
            Post(author: "Ellen Fairweather", role: "Packing house QA", region: "Hudson Valley, NY", hue: 0.47,
                 title: "Late scab turning up in storage",
                 body: "Pinpoint scab is showing on fruit that looked clean at harvest — infections from late-summer rain. If your fruit goes into long storage, it can be worth keeping fall covers going in wet years.",
                 disease: .scab, tags: ["storage", "fruit"], daysAgo: 15, upvotes: 18, comments: []),
            Post(author: "Kwame Osei", role: "Extension specialist", region: "Tri-County Extension", hue: 0.13,
                 title: "What our fall urea rows looked like by March",
                 body: "Rows that got urea after harvest had visibly more broken-down leaves by March, and our spore traps over those rows caught far fewer ascospores. Apply after harvest, just before or right after leaf drop.",
                 disease: .scab, tags: ["research", "sanitation"], daysAgo: 20, upvotes: 64,
                 comments: [("Jordan Pike", "Is this something a small orchard can do with a backpack sprayer?"),
                            ("Kwame Osei", "Yes — the goal is just to wet the leaves on the ground. Coverage matters more than equipment.")]),
            Post(author: "Ana Ruiz", role: "Family orchard", region: "Apple Hill, CA", hue: 0.02,
                 title: "Yellow blotches that weren't a disease",
                 body: "Some of our Honeycrisp leaves get yellow blotches every summer. Turned out to be zonal leaf chlorosis — a physiological disorder, not a pathogen. The scanner called them healthy, which matched what the diagnostic lab told us.",
                 disease: .healthy, tags: ["question", "honeycrisp"], daysAgo: 26, upvotes: 22, comments: []),
            Post(author: "Dale Henshaw", role: "Orchard manager", region: "Wenatchee, WA", hue: 0.08,
                 title: "Our spring plan: copper at green tip, then switch",
                 body: "Copper from silver tip to green tip, captan through tight cluster, and a DMI plus captan when the forecast shows a long wetting period. Never two DMIs back-to-back.",
                 disease: .scab, tags: ["spray timing", "spring"], daysAgo: 34, upvotes: 35, comments: []),
            Post(author: "Jordan Pike", role: "New grower", region: "Hood River, OR", hue: 0.58,
                 title: "The Mills table saved me a spray",
                 body: "Rain only kept the leaves wet for 6 hours at 48°F — not enough for a scab infection. Skipped the spray, scouted 12 days later, and it was clean.",
                 disease: .scab, tags: ["forecast"], daysAgo: 41, upvotes: 19, comments: []),
            Post(author: "Ellen Fairweather", role: "Packing house QA", region: "Hudson Valley, NY", hue: 0.47,
                 title: "Best way to number trees for the map?",
                 body: "We use Block-Row-Position (A-03-07). Makes it easy to find a tree again from the map and compare it season to season.",
                 disease: nil, tags: ["question", "mapping"], daysAgo: 48, upvotes: 15, comments: []),
            Post(author: "Priya Natarajan", role: "Extension agent", region: "Yakima, WA", hue: 0.75,
                 title: "Mildew loves dry, humid heat",
                 body: "Rainy years we barely see mildew — it's the warm, humid stretches without rain that blow it up. Tighten sulfur intervals then, but not above about 85°F.",
                 disease: .powderyMildew, tags: ["weather", "summer"], daysAgo: 72, upvotes: 28, comments: []),
            Post(author: "Ana Ruiz", role: "Family orchard", region: "Apple Hill, CA", hue: 0.02,
                 title: "Cedar galls are out — start rust sprays",
                 body: "Orange jelly horns on the cedars this morning after the rain. That's the spore release. If you're near junipers, keep protection on from pink through second cover.",
                 disease: .rust, tags: ["spring", "alert"], daysAgo: 160, upvotes: 44, comments: []),
        ]
        for post in posts {
            let created = Date.now.addingTimeInterval(-post.daysAgo * 86_400)
            let note = CommunityNote(authorName: post.author, authorRole: post.role, authorRegion: post.region, avatarHue: post.hue,
                                     title: post.title, body: post.body, disease: post.disease, tags: post.tags,
                                     createdAt: created, upvotes: post.upvotes)
            context.insert(note)
            for (i, (author, body)) in post.comments.enumerated() {
                let comment = NoteComment(authorName: author, body: body, createdAt: created.addingTimeInterval(Double(i + 1) * 5400))
                context.insert(comment)
                comment.note = note
            }
        }
    }
}
