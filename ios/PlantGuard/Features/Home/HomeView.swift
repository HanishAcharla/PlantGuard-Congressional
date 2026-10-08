import Charts
import SwiftData
import SwiftUI

struct HomeView: View {
    @Environment(AppRouter.self) private var router
    @Query private var orchards: [Orchard]
    @Query private var trees: [Tree]
    @Query(sort: \Scan.date, order: .reverse) private var scans: [Scan]
    @Query(sort: \TreatmentRecord.scheduledDate) private var treatments: [TreatmentRecord]
    @AppStorage("climateID") private var climateID = ClimateProfile.appleHill.id
    @AppStorage("growerName") private var growerName = ""
    @State private var showAddTreatment = false

    var body: some View {
        let analytics = OrchardAnalytics(trees: trees, scans: scans)
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                header
                HealthHeroCard(analytics: analytics, treeCount: trees.count, dueCount: dueTreatments.count)
                RiskBanner(climate: ClimateProfile.with(id: climateID))
                quickActions
                attention(analytics)
                recent
                toolkit
                upcoming
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
        }
        .tabBarSafeArea()
        .screenBackground()
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showAddTreatment) { AddTreatmentView() }
    }

    private var dueTreatments: [TreatmentRecord] {
        let horizon = Date.now.addingTimeInterval(21 * 86_400)
        return treatments.filter { $0.status == .planned && $0.scheduledDate < horizon }
    }

    private var greeting: String {
        let h = Calendar.current.component(.hour, from: .now)
        let part = h < 12 ? "Good morning" : h < 17 ? "Good afternoon" : "Good evening"
        return growerName.isEmpty ? part : "\(part), \(growerName)"
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 6) {
                Text(Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                    .kickerStyle()
                Text(greeting).font(.display(30)).foregroundStyle(Theme.textPrimary)
                if let orchard = orchards.first {
                    Label("\(orchard.name) · \(Season.current.label)", systemImage: "mappin.and.ellipse")
                        .font(.system(size: 13)).foregroundStyle(Theme.textSecondary)
                }
            }
            Spacer()
            NavigationLink(value: Route.settings) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 17)).foregroundStyle(Theme.textSecondary)
                    .frame(width: 42, height: 42)
                    .background(Circle().fill(.ultraThinMaterial))
                    .overlay(Circle().strokeBorder(Theme.hairline, lineWidth: 1))
            }
        }
    }

    private var quickActions: some View {
        HStack(spacing: 12) {
            QuickAction(symbol: "viewfinder", title: "Scan", color: Theme.rust) { router.startScan() }
            QuickAction(symbol: "map.fill", title: "Orchard", color: Theme.sage) { router.tab = .orchard }
            QuickAction(symbol: "drop.fill", title: "Log spray", color: Color(hex: 0x6FA8DC)) { showAddTreatment = true }
            NavigationLink(value: Route.forecast) {
                QuickActionLabel(symbol: "cloud.sun.rain.fill", title: "Forecast", color: Theme.amber)
            }
            .buttonStyle(PressableStyle())
        }
    }

    private struct AttentionItem: Identifiable {
        let tree: Tree
        let disease: Disease
        let streak: Int
        var id: String { tree.code }
    }

    @ViewBuilder
    private func attention(_ analytics: OrchardAnalytics) -> some View {
        let infected = trees.compactMap { tree -> AttentionItem? in
            guard let d = analytics.currentStatus(of: tree.code, lookback: 1), d.isDisease else { return nil }
            return AttentionItem(tree: tree, disease: d, streak: analytics.streak(of: tree.code))
        }
        let flagged = infected
            .sorted { ($0.streak, $0.tree.isFlagged ? 1 : 0) > ($1.streak, $1.tree.isFlagged ? 1 : 0) }
            .prefix(10)

        if !flagged.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeader(kicker: "Needs attention", title: "\(infected.count) trees to check", actionTitle: "Map") { router.tab = .orchard }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(Array(flagged)) { item in
                            NavigationLink(value: Route.tree(item.tree.code)) {
                                AttentionCard(tree: item.tree, disease: item.disease, streak: item.streak)
                            }
                            .buttonStyle(PressableStyle())
                        }
                    }
                    .padding(.vertical, 4)
                }
                .scrollClipDisabled()
            }
        }
    }

    private var recent: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(kicker: "History", title: "Recent scans")
                .overlay(alignment: .bottomTrailing) {
                    if !scans.isEmpty {
                        NavigationLink(value: Route.history) {
                            Text("See all").font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.rustLight)
                        }
                    }
                }
            if scans.isEmpty {
                GlassCard {
                    EmptyStateView(symbol: "viewfinder", title: "No scans yet", message: "Tap the scan button to photograph a leaf.")
                }
            } else {
                GlassCard(padding: 6) {
                    VStack(spacing: 0) {
                        ForEach(scans.prefix(4)) { scan in
                            NavigationLink(value: Route.scan(scan.id)) { ScanRow(scan: scan) }
                                .buttonStyle(PressableStyle())
                            if scan.id != scans.prefix(4).last?.id {
                                Divider().overlay(Theme.hairline).padding(.leading, 74)
                            }
                        }
                    }
                }
            }
        }
    }

    private var toolkit: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(kicker: "Toolkit", title: "Everything else")
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ToolTile(route: .history, symbol: "clock.arrow.circlepath", title: "History", subtitle: "\(scans.count) scans", color: Theme.sage)
                ToolTile(route: .database, symbol: "cylinder.split.1x2.fill", title: "Database", subtitle: "Browse & export", color: Color(hex: 0x6FA8DC))
                ToolTile(route: .treatments, symbol: "cross.vial.fill", title: "Treatments", subtitle: "\(treatments.filter { $0.status == .planned }.count) planned", color: Theme.rust)
                ToolTile(route: .library, symbol: "books.vertical.fill", title: "Disease library", subtitle: "6 conditions", color: Color(hex: 0x9B88F2))
                ToolTile(route: .forecast, symbol: "cloud.sun.rain.fill", title: "Risk forecast", subtitle: "Mills-table model", color: Theme.amber)
                ToolTile(route: .modelLab, symbol: "cpu.fill", title: "Model lab", subtitle: "ResNet-50 on device", color: Color(hex: 0xD06A9E))
                ToolTile(route: .report, symbol: "doc.richtext.fill", title: "Season report", subtitle: "Share as PDF", color: Theme.mint)
                ToolTile(route: .settings, symbol: "slider.horizontal.3", title: "Settings", subtitle: "Orchard & data", color: Theme.parchment)
            }
        }
    }

    @ViewBuilder
    private var upcoming: some View {
        let next = treatments.filter { $0.status == .planned && $0.scheduledDate >= Calendar.current.startOfDay(for: .now) }.prefix(3)
        if !next.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeader(kicker: "Planner", title: "Coming up")
                    .overlay(alignment: .bottomTrailing) {
                        NavigationLink(value: Route.treatments) {
                            Text("All").font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.rustLight)
                        }
                    }
                VStack(spacing: 10) {
                    ForEach(Array(next)) { t in TreatmentRow(treatment: t) }
                }
            }
        }
    }
}

private struct HealthHeroCard: View {
    let analytics: OrchardAnalytics
    let treeCount: Int
    let dueCount: Int

    var body: some View {
        let season = analytics.latestSeason
        let rate = season.map(analytics.infectionRate(in:)) ?? 0
        let scanned = season.map(analytics.scannedCount(in:)) ?? 0
        let infected = season.map(analytics.infectedCount(in:)) ?? 0
        let healthy = scanned == 0 ? 1 : 1 - rate

        GlassCard(padding: 20, tint: Theme.canopy500) {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 20) {
                    ZStack {
                        ConfidenceRing(value: healthy, color: healthy > 0.8 ? Theme.sage : healthy > 0.65 ? Theme.amber : Theme.danger, lineWidth: 12)
                        VStack(spacing: 0) {
                            Text("\(Int((healthy * 100).rounded()))").font(.display(34)).foregroundStyle(Theme.textPrimary)
                            Text("% healthy").font(.system(size: 11)).foregroundStyle(Theme.textTertiary)
                        }
                    }
                    .frame(width: 112, height: 112)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Orchard health").kickerStyle(Theme.sage)
                        HStack(spacing: 18) {
                            StatBlock(value: "\(treeCount)", label: "trees")
                            StatBlock(value: "\(scanned)", label: "scanned")
                        }
                        HStack(spacing: 18) {
                            StatBlock(value: "\(infected)", label: "infected", color: infected > 0 ? Theme.rustLight : Theme.textPrimary)
                            StatBlock(value: "\(dueCount)", label: "sprays due")
                        }
                    }
                }

                if analytics.seasons.count > 1 {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Infection rate by season").font(.system(size: 12, weight: .medium)).foregroundStyle(Theme.textSecondary)
                            Spacer()
                            if let s = season {
                                let prev = analytics.infectionRate(in: s.previousGrowing)
                                let delta = rate - prev
                                Label("\(delta >= 0 ? "+" : "")\(Int((delta * 100).rounded())) pts", systemImage: delta > 0 ? "arrow.up.right" : "arrow.down.right")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(delta > 0 ? Theme.rustLight : Theme.sage)
                            }
                        }
                        Chart(analytics.seasons) { s in
                            AreaMark(x: .value("Season", s.shortLabel), y: .value("Rate", analytics.infectionRate(in: s)))
                                .foregroundStyle(LinearGradient(colors: [Theme.rust.opacity(0.45), .clear], startPoint: .top, endPoint: .bottom))
                                .interpolationMethod(.catmullRom)
                            LineMark(x: .value("Season", s.shortLabel), y: .value("Rate", analytics.infectionRate(in: s)))
                                .foregroundStyle(Theme.rustLight)
                                .lineStyle(StrokeStyle(lineWidth: 2.2, lineCap: .round))
                                .interpolationMethod(.catmullRom)
                            if s == season {
                                PointMark(x: .value("Season", s.shortLabel), y: .value("Rate", analytics.infectionRate(in: s)))
                                    .foregroundStyle(Theme.parchment).symbolSize(40)
                            }
                        }
                        .chartYAxis(.hidden)
                        .chartXAxis {
                            AxisMarks { _ in AxisValueLabel().font(.system(size: 9)).foregroundStyle(Theme.textTertiary) }
                        }
                        .frame(height: 70)
                    }
                }
            }
        }
    }
}

private struct RiskBanner: View {
    let climate: ClimateProfile

    var body: some View {
        let today = WeatherSimulator.day(.now, climate: climate)
        let top = RiskModel.risks(for: today).first!
        NavigationLink(value: Route.forecast) {
            GlassCard(padding: 16, tint: top.level.color) {
                HStack(spacing: 14) {
                    Image(systemName: today.symbol)
                        .symbolRenderingMode(.multicolor)
                        .font(.system(size: 30))
                        .frame(width: 46)
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text("\(top.disease.shortName) risk today").font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.textPrimary)
                            Text(top.level.label).font(.system(size: 11, weight: .bold))
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .foregroundStyle(top.level.color)
                                .background(Capsule().fill(top.level.color.opacity(0.16)))
                        }
                        Text("\(Int(today.highF))° / \(Int(today.lowF))° · \(today.rainMM > 0 ? "\(today.rainMM.formatted()) mm rain" : "dry") · \(Int(today.wetHours)) h leaf wetness")
                            .font(.system(size: 12)).foregroundStyle(Theme.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.textTertiary)
                }
            }
        }
        .buttonStyle(PressableStyle())
    }
}

private struct QuickActionLabel: View {
    let symbol: String
    let title: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(color.mix(with: .white, by: 0.15))
                .frame(width: 52, height: 52)
                .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(color.opacity(0.16)))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(color.opacity(0.3), lineWidth: 1))
            Text(title).font(.system(size: 12, weight: .medium)).foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct QuickAction: View {
    let symbol: String
    let title: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            QuickActionLabel(symbol: symbol, title: title, color: color)
        }
        .buttonStyle(PressableStyle())
    }
}

private struct AttentionCard: View {
    let tree: Tree
    let disease: Disease
    let streak: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .topTrailing) {
                if let scan = tree.latestScan {
                    ScanThumbnail(scan: scan, cornerRadius: 16)
                } else {
                    LeafArt(disease: disease, seed: tree.code.hashValue)
                }
                if tree.isFlagged {
                    Image(systemName: "flag.fill").font(.system(size: 11)).foregroundStyle(.white)
                        .padding(6).background(Circle().fill(Theme.rust)).padding(6)
                }
            }
            .frame(width: 150, height: 110)
            Text(tree.code).font(.mono(15, weight: .semibold)).foregroundStyle(Theme.textPrimary)
            DiseaseBadge(disease: disease, compact: true)
            Text(streak > 1 ? "\(streak) seasons in a row" : "New this season")
                .font(.system(size: 11)).foregroundStyle(streak > 1 ? Theme.rustLight : Theme.textTertiary)
        }
        .padding(12)
        .frame(width: 174, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(.ultraThinMaterial))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(disease.color.opacity(0.25), lineWidth: 1))
    }
}

private struct ToolTile: View {
    let route: Route
    let symbol: String
    let title: String
    let subtitle: String
    let color: Color

    var body: some View {
        NavigationLink(value: route) {
            VStack(alignment: .leading, spacing: 12) {
                IconTile(symbol: symbol, color: color)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.textPrimary)
                    Text(subtitle).font(.system(size: 12)).foregroundStyle(Theme.textTertiary)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(.ultraThinMaterial))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Theme.hairline, lineWidth: 1))
        }
        .buttonStyle(PressableStyle())
    }
}

struct ScanRow: View {
    let scan: Scan

    var body: some View {
        HStack(spacing: 14) {
            ScanThumbnail(scan: scan, cornerRadius: 14).frame(width: 56, height: 56)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(scan.disease.name).font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.textPrimary)
                    Circle().fill(scan.disease.color).frame(width: 6, height: 6)
                }
                Text("\(scan.tree?.code ?? "Unassigned") · \(scan.date.formatted(.dateTime.month(.abbreviated).day().year()))")
                    .font(.system(size: 12)).foregroundStyle(Theme.textTertiary)
            }
            Spacer()
            Text(scan.confidence, format: .percent.precision(.fractionLength(0)))
                .font(.mono(13)).foregroundStyle(Theme.textSecondary)
            Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.textTertiary)
        }
        .padding(10)
        .contentShape(Rectangle())
    }
}

struct TreatmentRow: View {
    let treatment: TreatmentRecord

    var body: some View {
        HStack(spacing: 14) {
            VStack(spacing: 0) {
                Text(treatment.scheduledDate.formatted(.dateTime.month(.abbreviated))).font(.system(size: 10, weight: .bold)).textCase(.uppercase)
                    .foregroundStyle(Theme.rustLight)
                Text(treatment.scheduledDate.formatted(.dateTime.day())).font(.display(20)).foregroundStyle(Theme.textPrimary)
            }
            .frame(width: 48, height: 50)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.parchment.opacity(0.06)))
            VStack(alignment: .leading, spacing: 4) {
                Text(treatment.title).font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.textPrimary).lineLimit(2)
                HStack(spacing: 6) {
                    Image(systemName: treatment.category.symbol).font(.system(size: 10))
                    Text("\(treatment.targetLabel) · \(treatment.disease.shortName)")
                }
                .font(.system(size: 12)).foregroundStyle(Theme.textTertiary)
            }
            Spacer()
            statusTag
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(.ultraThinMaterial))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Theme.hairline, lineWidth: 1))
    }

    @ViewBuilder
    private var statusTag: some View {
        switch treatment.status {
        case .applied: Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.sage)
        case .skipped: Image(systemName: "xmark.circle").foregroundStyle(Theme.textTertiary)
        case .planned:
            let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: .now), to: Calendar.current.startOfDay(for: treatment.scheduledDate)).day ?? 0
            Text(days <= 0 ? "Today" : days == 1 ? "Tomorrow" : "in \(days)d")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(days <= 2 ? Theme.rustLight : Theme.textSecondary)
        }
    }
}
