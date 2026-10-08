import Charts
import SwiftData
import SwiftUI

struct SeasonsView: View {
    @Query(sort: \Tree.code) private var trees: [Tree]
    @Query private var scans: [Scan]
    @Query private var orchards: [Orchard]
    @State private var selected: Season?

    var body: some View {
        let analytics = OrchardAnalytics(trees: trees, scans: scans)
        let focus = selected ?? analytics.latestSeason

        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Cross-season tracking").kickerStyle()
                    Text("Seasons").font(.display(34)).foregroundStyle(Theme.textPrimary)
                    Text("How disease moves through the orchard from one season to the next.")
                        .font(.system(size: 14)).foregroundStyle(Theme.textSecondary)
                }

                if let focus, !analytics.seasons.isEmpty {
                    seasonPicker(analytics, focus: focus)
                    SeasonHero(analytics: analytics, season: focus)
                    PrevalenceChart(analytics: analytics, focus: focus) { selected = $0 }
                    TransitionsCard(analytics: analytics, season: focus)
                    BlockHeatmap(analytics: analytics, blocks: orchards.first?.blocks.sorted { $0.letter < $1.letter } ?? [], focus: focus) { selected = $0 }
                    ChronicTreesCard(analytics: analytics)
                    SeasonalityCard(analytics: analytics)
                } else {
                    GlassCard {
                        EmptyStateView(symbol: "calendar.badge.clock", title: "No seasons yet",
                                       message: "Assign scans to trees and each season's results will show up here.")
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
        }
        .tabBarSafeArea()
        .screenBackground()
        .toolbar(.hidden, for: .navigationBar)
    }

    private func seasonPicker(_ analytics: OrchardAnalytics, focus: Season) -> some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(analytics.seasons) { s in
                        Button {
                            Haptics.tap()
                            withAnimation(.snappy) { selected = s }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: s.kind.symbol).font(.system(size: 11))
                                Text(s.label).font(.system(size: 13, weight: .semibold))
                            }
                            .padding(.horizontal, 13).padding(.vertical, 9)
                            .foregroundStyle(s == focus ? Theme.canopy950 : Theme.textSecondary)
                            .background(Capsule().fill(s == focus ? Theme.parchment : Theme.parchment.opacity(0.07)))
                        }
                        .buttonStyle(.plain)
                        .id(s)
                    }
                }
            }
            .scrollClipDisabled()
            .onAppear { proxy.scrollTo(focus, anchor: .trailing) }
        }
    }
}

private struct SeasonHero: View {
    let analytics: OrchardAnalytics
    let season: Season

    var body: some View {
        let rate = analytics.infectionRate(in: season)
        let prev = season.previousGrowing
        let lastYear = Season(year: season.year - 1, kind: season.kind)
        let hasPrev = analytics.scannedCount(in: prev) > 0
        let hasYear = analytics.scannedCount(in: lastYear) > 0
        let prevalence = analytics.prevalence(in: season).filter { $0.key.isDisease }.sorted { $0.value > $1.value }

        GlassCard(padding: 20, tint: rate > 0.25 ? Theme.rust : Theme.canopy500) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(season.label).kickerStyle(Theme.sage)
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("\(Int((rate * 100).rounded()))").font(.display(56)).foregroundStyle(Theme.textPrimary)
                                .contentTransition(.numericText())
                            Text("% infected").font(.system(size: 15)).foregroundStyle(Theme.textSecondary)
                        }
                    }
                    Spacer()
                    Image(systemName: season.kind.symbol).font(.system(size: 34)).foregroundStyle(Theme.amber.opacity(0.8))
                        .symbolRenderingMode(.hierarchical)
                }
                Text("\(analytics.infectedCount(in: season)) of \(analytics.scannedCount(in: season)) scanned trees showed disease.")
                    .font(.system(size: 13)).foregroundStyle(Theme.textSecondary)
                HStack(spacing: 8) {
                    if hasPrev { DeltaPill(label: "vs \(prev.shortLabel)", delta: rate - analytics.infectionRate(in: prev)) }
                    if hasYear { DeltaPill(label: "vs \(lastYear.shortLabel)", delta: rate - analytics.infectionRate(in: lastYear)) }
                }
                if !prevalence.isEmpty {
                    HStack(spacing: 8) {
                        ForEach(prevalence.prefix(3), id: \.key) { d, n in
                            HStack(spacing: 5) {
                                Circle().fill(d.color).frame(width: 7, height: 7)
                                Text("\(d.shortName) \(n)").font(.system(size: 12, weight: .medium)).foregroundStyle(Theme.textSecondary)
                            }
                        }
                    }
                }
            }
        }
    }
}

private struct DeltaPill: View {
    let label: String
    let delta: Double

    var body: some View {
        let up = delta > 0.005
        let color = up ? Theme.rustLight : Theme.sage
        HStack(spacing: 5) {
            Image(systemName: up ? "arrow.up.right" : "arrow.down.right").font(.system(size: 10, weight: .bold))
            Text("\(up ? "+" : "")\(Int((delta * 100).rounded())) pts").font(.system(size: 12, weight: .bold))
            Text(label).font(.system(size: 11)).foregroundStyle(Theme.textTertiary)
        }
        .lineLimit(1)
        .fixedSize()
        .foregroundStyle(color)
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(Capsule().fill(color.opacity(0.12)))
    }
}

private struct PrevalenceChart: View {
    let analytics: OrchardAnalytics
    let focus: Season
    var onSelect: (Season) -> Void

    private struct Entry: Identifiable {
        let season: Season
        let disease: Disease
        let share: Double
        var id: String { "\(season.index)-\(disease.rawValue)" }
    }

    var body: some View {
        let entries = analytics.seasons.flatMap { s -> [Entry] in
            let n = Double(max(1, analytics.scannedCount(in: s)))
            let p = analytics.prevalence(in: s)
            return Disease.diseases.map { Entry(season: s, disease: $0, share: Double(p[$0] ?? 0) / n) }
        }

        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Prevalence by season").kickerStyle(Theme.textTertiary)
                Text("Share of scanned trees with each disease").font(.system(size: 13)).foregroundStyle(Theme.textSecondary)
                Chart(entries) { e in
                    BarMark(x: .value("Season", e.season.shortLabel), y: .value("Share", e.share))
                        .foregroundStyle(by: .value("Disease", e.disease.shortName))
                        .opacity(e.season == focus ? 1 : 0.62)
                        .cornerRadius(3)
                }
                .chartForegroundStyleScale(domain: Disease.diseases.map(\.shortName), range: Disease.diseases.map(\.color))
                .chartYAxis {
                    AxisMarks(values: [0, 0.1, 0.2, 0.3, 0.4]) { v in
                        AxisGridLine().foregroundStyle(Theme.hairline)
                        AxisValueLabel { Text("\(Int((v.as(Double.self) ?? 0) * 100))%").font(.system(size: 9)).foregroundStyle(Theme.textTertiary) }
                    }
                }
                .chartXAxis {
                    AxisMarks { _ in AxisValueLabel().font(.system(size: 9)).foregroundStyle(Theme.textTertiary) }
                }
                .chartLegend(position: .bottom, spacing: 12) {
                    HStack(spacing: 10) {
                        ForEach(Disease.diseases) { d in
                            HStack(spacing: 4) {
                                Circle().fill(d.color).frame(width: 7, height: 7)
                                Text(d.shortName).font(.system(size: 10)).foregroundStyle(Theme.textSecondary)
                            }
                        }
                    }
                }
                .chartOverlay { proxy in
                    GeometryReader { geo in
                        Rectangle().fill(.clear).contentShape(Rectangle())
                            .onTapGesture { location in
                                let originX = proxy.plotFrame.map { geo[$0].origin.x } ?? 0
                                if let label: String = proxy.value(atX: location.x - originX), let s = analytics.seasons.first(where: { $0.shortLabel == label }) {
                                    Haptics.tap()
                                    withAnimation(.snappy) { onSelect(s) }
                                }
                            }
                    }
                }
                .frame(height: 220)
            }
        }
    }
}

private struct TransitionsCard: View {
    let analytics: OrchardAnalytics
    let season: Season

    var body: some View {
        let prev = season.previousGrowing
        let t = analytics.transitions(from: prev, to: season)
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("What changed").kickerStyle(Theme.textTertiary)
                Text("\(prev.label) → \(season.label)").font(.display(20)).foregroundStyle(Theme.textPrimary)
                if t.total == 0 {
                    Text("No trees were scanned in both seasons.").font(.system(size: 13)).foregroundStyle(Theme.textSecondary)
                } else {
                    GeometryReader { geo in
                        HStack(spacing: 3) {
                            segment(t.stayedHealthy, of: t.total, width: geo.size.width, color: Color(hex: 0x5DAF78))
                            segment(t.recovered, of: t.total, width: geo.size.width, color: Theme.mint)
                            segment(t.newlyInfected, of: t.total, width: geo.size.width, color: Theme.rustLight)
                            segment(t.stayedInfected, of: t.total, width: geo.size.width, color: Theme.danger)
                        }
                    }
                    .frame(height: 12)
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        tile("Stayed healthy", t.stayedHealthy, "checkmark.circle.fill", Color(hex: 0x5DAF78))
                        tile("Recovered", t.recovered, "arrow.uturn.up.circle.fill", Theme.mint)
                        tile("Newly infected", t.newlyInfected, "plus.circle.fill", Theme.rustLight)
                        tile("Still infected", t.stayedInfected, "arrow.triangle.2.circlepath.circle.fill", Theme.danger)
                    }
                    Text("Based on \(t.total) trees scanned in both seasons.").font(.system(size: 11)).foregroundStyle(Theme.textTertiary)
                }
            }
        }
    }

    private func segment(_ n: Int, of total: Int, width: CGFloat, color: Color) -> some View {
        Capsule().fill(color).frame(width: max(n > 0 ? 4 : 0, (width - 9) * CGFloat(n) / CGFloat(max(1, total))))
    }

    private func tile(_ label: String, _ n: Int, _ symbol: String, _ color: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol).font(.system(size: 18)).foregroundStyle(color)
            VStack(alignment: .leading, spacing: 0) {
                Text("\(n)").font(.display(22)).foregroundStyle(Theme.textPrimary).contentTransition(.numericText())
                Text(label).font(.system(size: 11)).foregroundStyle(Theme.textTertiary)
            }
            Spacer()
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(color.opacity(0.08)))
    }
}

private struct BlockHeatmap: View {
    let analytics: OrchardAnalytics
    let blocks: [OrchardBlock]
    let focus: Season
    var onSelect: (Season) -> Void

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Blocks × seasons").kickerStyle(Theme.textTertiary)
                Text("Infection rate in each block, season by season").font(.system(size: 13)).foregroundStyle(Theme.textSecondary)
                VStack(spacing: 5) {
                    ForEach(blocks) { block in
                        HStack(spacing: 5) {
                            VStack(alignment: .leading, spacing: 0) {
                                Text(block.letter).font(.mono(13, weight: .bold)).foregroundStyle(Theme.textPrimary)
                                Text(block.variety).font(.system(size: 8)).foregroundStyle(Theme.textTertiary).lineLimit(1)
                            }
                            .frame(width: 52, alignment: .leading)
                            ForEach(analytics.seasons) { s in
                                let rate = analytics.blockRate(block.letter, in: s)
                                RoundedRectangle(cornerRadius: 5, style: .continuous)
                                    .fill(rate.map { heat($0) } ?? Theme.parchment.opacity(0.04))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                                            .strokeBorder(s == focus ? Theme.parchment : .clear, lineWidth: 1.5)
                                    )
                                    .overlay {
                                        if let rate, rate >= 0.1 {
                                            Text("\(Int((rate * 100).rounded()))").font(.system(size: 8, weight: .bold)).foregroundStyle(.white.opacity(0.85))
                                        }
                                    }
                                    .frame(height: 30)
                                    .onTapGesture {
                                        Haptics.tap()
                                        withAnimation(.snappy) { onSelect(s) }
                                    }
                            }
                        }
                    }
                    HStack(spacing: 5) {
                        Color.clear.frame(width: 52, height: 1)
                        ForEach(analytics.seasons) { s in
                            Text(s.shortLabel).font(.system(size: 7.5, weight: .medium)).foregroundStyle(s == focus ? Theme.textPrimary : Theme.textTertiary)
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
                HStack(spacing: 6) {
                    Text("0%").font(.system(size: 10)).foregroundStyle(Theme.textTertiary)
                    LinearGradient(colors: [heat(0), heat(0.2), heat(0.45)], startPoint: .leading, endPoint: .trailing)
                        .frame(height: 6).clipShape(Capsule())
                    Text("45%+").font(.system(size: 10)).foregroundStyle(Theme.textTertiary)
                }
            }
        }
    }

    /// Sequential rust ramp: near-surface green-black for 0% to vivid rust at 45%+.
    private func heat(_ r: Double) -> Color {
        let t = min(1, r / 0.45)
        return Color(hex: 0x1E3527).mix(with: Color(hex: 0xE0663A), by: t)
    }
}

private struct ChronicTreesCard: View {
    let analytics: OrchardAnalytics

    var body: some View {
        let chronic = Array(analytics.chronicTrees().prefix(6))
        if !chronic.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(kicker: "Repeat offenders", title: "Chronic trees")
                Text("Infected in 3 or more seasons — usually an overwintering source worth sanitising or replanting.")
                    .font(.system(size: 13)).foregroundStyle(Theme.textSecondary)
                ForEach(chronic) { c in
                    NavigationLink(value: Route.tree(c.code)) {
                        GlassCard(padding: 14, cornerRadius: 20, tint: c.dominant.color) {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Text(c.code).font(.mono(16, weight: .bold)).foregroundStyle(Theme.textPrimary)
                                    DiseaseBadge(disease: c.dominant, compact: true)
                                    Spacer()
                                    Text("\(c.infectedSeasons) seasons").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.rustLight)
                                }
                                SeasonStrip(timeline: analytics.timeline(of: c.code), dotSize: 12, showsLabels: false)
                            }
                        }
                    }
                    .buttonStyle(PressableStyle())
                }
            }
        }
    }
}

private struct SeasonalityCard: View {
    let analytics: OrchardAnalytics

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("When each disease peaks").kickerStyle(Theme.textTertiary)
                ForEach(Disease.diseases) { d in
                    let profile = analytics.seasonality(of: d)
                    HStack(spacing: 10) {
                        Text(d.shortName).font(.system(size: 13, weight: .medium)).foregroundStyle(Theme.textSecondary).frame(width: 74, alignment: .leading)
                        ForEach([SeasonKind.spring, .summer, .fall], id: \.self) { k in
                            let share = profile[k] ?? 0
                            VStack(spacing: 3) {
                                GeometryReader { geo in
                                    VStack {
                                        Spacer(minLength: 0)
                                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                                            .fill(d.color.opacity(0.25 + 0.75 * share))
                                            .frame(height: max(3, geo.size.height * share))
                                    }
                                }
                                .frame(height: 34)
                                Text(k.name).font(.system(size: 9)).foregroundStyle(Theme.textTertiary)
                            }
                        }
                    }
                }
            }
        }
    }
}
