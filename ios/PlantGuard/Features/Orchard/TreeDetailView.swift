import Charts
import SwiftData
import SwiftUI

struct TreeDetailView: View {
    @Bindable var tree: Tree
    @Environment(AppRouter.self) private var router
    @Environment(\.modelContext) private var context
    @Query private var allTrees: [Tree]
    @Query private var allScans: [Scan]
    @State private var showAddTreatment = false

    var body: some View {
        let analytics = OrchardAnalytics(trees: allTrees, scans: allScans)
        let latest = tree.latestScan
        let status = latest?.disease
        let scans = tree.sortedScans

        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                hero(latest: latest, status: status)

                GlassCard {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text("Across seasons").kickerStyle(Theme.sage)
                            Spacer()
                            let infected = analytics.infectedSeasons(of: tree.code)
                            Text("\(infected) of \(analytics.timeline(of: tree.code).filter { $0.disease != nil }.count) scanned seasons infected")
                                .font(.system(size: 11)).foregroundStyle(Theme.textTertiary)
                        }
                        SeasonStrip(timeline: analytics.timeline(of: tree.code), dotSize: 18)
                        let streak = analytics.streak(of: tree.code)
                        if streak >= 2 {
                            Label("Infected \(streak) seasons in a row — likely an overwintering source on or under this tree.",
                                  systemImage: "arrow.triangle.2.circlepath")
                                .font(.system(size: 13)).foregroundStyle(Theme.rustLight)
                        }
                    }
                }

                if scans.count > 1 { confidenceChart(scans) }

                if let latest {
                    let prior = Set(scans.filter { $0.disease == latest.disease && $0.season != latest.season }.map(\.season)).count
                    CarePlanCard(plan: CarePlanner.plan(for: latest.disease, confidence: latest.confidence, priorSeasonsWithDisease: prior))
                }

                actions

                if !scans.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeader(kicker: "Scans", title: "\(scans.count) on record")
                        GlassCard(padding: 6) {
                            VStack(spacing: 0) {
                                ForEach(scans.prefix(12)) { scan in
                                    NavigationLink(value: Route.scan(scan.id)) { ScanRow(scan: scan) }.buttonStyle(PressableStyle())
                                }
                            }
                        }
                    }
                }

                let treatments = tree.treatments.sorted { $0.scheduledDate > $1.scheduledDate }
                if !treatments.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeader(kicker: "Treatments", title: "Work on this tree")
                        ForEach(treatments) { TreatmentRow(treatment: $0) }
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Notes").kickerStyle(Theme.textTertiary)
                    TextField("Observations, cankers, nearby junipers…", text: $tree.notes, axis: .vertical)
                        .lineLimit(3...8)
                        .padding(14)
                        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.parchment.opacity(0.06)))
                        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Theme.hairline, lineWidth: 1))
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 30)
        }
        .tabBarSafeArea()
        .screenBackground()
        .navigationTitle(tree.code)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showAddTreatment) { AddTreatmentView(treeCode: tree.code, disease: status) }
    }

    private func hero(latest: Scan?, status: Disease?) -> some View {
        ZStack(alignment: .bottomLeading) {
            Group {
                if let data = latest?.imageData, let img = UIImage(data: data) {
                    Image(uiImage: img).resizable().scaledToFill()
                } else {
                    ZStack(alignment: .topTrailing) {
                        LinearGradient(colors: [(status ?? .healthy).color.opacity(0.35), Theme.canopy900], startPoint: .topTrailing, endPoint: .bottomLeading)
                        LeafArt(disease: status ?? .healthy, seed: latest?.artSeed ?? tree.row * 17)
                            .frame(width: 170, height: 170)
                            .padding(.top, 8).padding(.trailing, 10)
                    }
                }
            }
            .frame(height: 250)
            .frame(maxWidth: .infinity)
            .clipped()
            .overlay(LinearGradient(colors: [.clear, Theme.canopy950.opacity(0.9)], startPoint: .center, endPoint: .bottom))

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text(tree.code).font(.mono(32, weight: .bold)).foregroundStyle(Theme.textPrimary)
                    if tree.isFlagged {
                        Image(systemName: "flag.fill").foregroundStyle(Theme.rust)
                    }
                }
                Text("\(tree.block?.name ?? "") · \(tree.variety) · planted \(String(tree.plantedYear)) · row \(tree.row), tree \(tree.position)")
                    .font(.system(size: 13)).foregroundStyle(Theme.textSecondary)
                if let status { DiseaseBadge(disease: status) }
            }
            .padding(18)
        }
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).strokeBorder(Theme.parchment.opacity(0.12), lineWidth: 1))
    }

    private func confidenceChart(_ scans: [Scan]) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Disease signal over time").kickerStyle(Theme.textTertiary)
                Chart(Array(scans.reversed())) { scan in
                    // Probability that the leaf was diseased at all (1 − P(healthy)).
                    let p = 1 - scan.probability(of: .healthy)
                    LineMark(x: .value("Date", scan.date), y: .value("Disease probability", p))
                        .foregroundStyle(Theme.parchment.opacity(0.35))
                        .interpolationMethod(.monotone)
                    PointMark(x: .value("Date", scan.date), y: .value("Disease probability", p))
                        .foregroundStyle(scan.disease.color)
                        .symbolSize(60)
                }
                .chartYScale(domain: 0...1)
                .chartXScale(range: .plotDimension(padding: 14))
                .chartYAxis {
                    AxisMarks(values: [0, 0.5, 1]) { v in
                        AxisGridLine().foregroundStyle(Theme.hairline)
                        AxisValueLabel { Text("\(Int((v.as(Double.self) ?? 0) * 100))%").font(.system(size: 9)).foregroundStyle(Theme.textTertiary) }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .month, count: 6)) { _ in
                        AxisValueLabel(format: .dateTime.month(.abbreviated).year(.twoDigits)).font(.system(size: 9)).foregroundStyle(Theme.textTertiary)
                    }
                }
                .frame(height: 150)
            }
        }
    }

    private var actions: some View {
        HStack(spacing: 10) {
            Button { router.startScan(treeCode: tree.code) } label: { Label("Scan", systemImage: "viewfinder") }
                .buttonStyle(PrimaryButtonStyle())
            Button { showAddTreatment = true } label: { Label("Treat", systemImage: "drop.fill") }
                .buttonStyle(SecondaryButtonStyle())
            Button {
                Haptics.tap()
                tree.isFlagged.toggle()
            } label: {
                Image(systemName: tree.isFlagged ? "flag.slash.fill" : "flag.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(tree.isFlagged ? Theme.rustLight : Theme.textPrimary)
                    .frame(width: 52, height: 52)
                    .background(Circle().fill(Theme.parchment.opacity(0.07)))
                    .overlay(Circle().strokeBorder(Theme.parchment.opacity(0.14), lineWidth: 1))
            }
            Button { router.showOnMap(tree.code) } label: {
                Image(systemName: "map.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .frame(width: 52, height: 52)
                    .background(Circle().fill(Theme.parchment.opacity(0.07)))
                    .overlay(Circle().strokeBorder(Theme.parchment.opacity(0.14), lineWidth: 1))
            }
        }
    }
}
