import Charts
import SwiftData
import SwiftUI

struct SeasonReportView: View {
    @Query private var orchards: [Orchard]
    @Query(sort: \Tree.code) private var trees: [Tree]
    @Query private var scans: [Scan]
    @Query(sort: \TreatmentRecord.scheduledDate) private var treatments: [TreatmentRecord]
    @State private var season: Season?
    @State private var pdfURL: URL?

    var body: some View {
        let analytics = OrchardAnalytics(trees: trees, scans: scans)
        let focus = season ?? analytics.latestSeason

        ScrollView {
            VStack(spacing: 18) {
                if let focus {
                    Picker("Season", selection: Binding(get: { focus }, set: { season = $0; pdfURL = nil })) {
                        ForEach(analytics.seasons.reversed()) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.menu)
                    .tint(Theme.rustLight)

                    let page = ReportPage(orchard: orchards.first, season: focus, analytics: analytics, trees: trees, treatments: treatments)
                    let scale: CGFloat = 0.57
                    page
                        .frame(width: ReportPage.size.width, height: ReportPage.size.height)
                        .scaleEffect(scale, anchor: .topLeading)
                        .frame(width: ReportPage.size.width * scale, height: ReportPage.size.height * scale, alignment: .topLeading)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .shadow(color: .black.opacity(0.5), radius: 24, y: 12)

                    if let pdfURL {
                        ShareLink(item: pdfURL, preview: SharePreview("\(focus.label) report")) {
                            Label("Share PDF", systemImage: "square.and.arrow.up")
                        }
                        .buttonStyle(PrimaryButtonStyle())
                    } else {
                        Button { pdfURL = render(page, name: focus.label) } label: { Label("Create PDF", systemImage: "doc.richtext") }
                            .buttonStyle(PrimaryButtonStyle())
                    }
                } else {
                    EmptyStateView(symbol: "doc.richtext", title: "No season data", message: "Scan some trees first.")
                }
            }
            .padding(.horizontal, 20)
        }
        .tabBarSafeArea()
        .screenBackground()
        .navigationTitle("Season report")
    }

    @MainActor
    private func render(_ page: ReportPage, name: String) -> URL? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("PlantGuard \(name).pdf")
        let renderer = ImageRenderer(content: page.frame(width: ReportPage.size.width, height: ReportPage.size.height))
        var box = CGRect(origin: .zero, size: ReportPage.size)
        guard let pdf = CGContext(url as CFURL, mediaBox: &box, nil) else { return nil }
        renderer.render { _, draw in
            pdf.beginPDFPage(nil)
            draw(pdf)
            pdf.endPDFPage()
            pdf.closePDF()
        }
        Haptics.success()
        return url
    }
}

/// A US-Letter "printed" report in light paper tones — designed to look good on paper and in Files.
struct ReportPage: View {
    static let size = CGSize(width: 612, height: 792)

    let orchard: Orchard?
    let season: Season
    let analytics: OrchardAnalytics
    let trees: [Tree]
    let treatments: [TreatmentRecord]

    private let ink = Color(hex: 0x10251B)
    private let paper = Color(hex: 0xFBF7EC)

    var body: some View {
        let rate = analytics.infectionRate(in: season)
        let prev = season.previousGrowing
        let prevalence = analytics.prevalence(in: season)
        let applied = treatments.filter { $0.status == .applied && Season(date: $0.scheduledDate) == season }
        let planned = treatments.filter { $0.status == .planned }.prefix(4)
        let chronic = analytics.chronicTrees().prefix(5)
        let blocks = orchard?.blocks.sorted { $0.letter < $1.letter } ?? []

        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("PLANTGUARD · SEASON REPORT").font(.system(size: 9, weight: .bold, design: .monospaced)).tracking(1.5).foregroundStyle(Theme.rust)
                    Text(season.label).font(.system(size: 34, weight: .semibold, design: .serif)).foregroundStyle(ink)
                    Text("\(orchard?.name ?? "Orchard") · \(orchard?.region ?? "")").font(.system(size: 12)).foregroundStyle(ink.opacity(0.6))
                }
                Spacer()
                Text("Generated \(Date.now.formatted(date: .abbreviated, time: .omitted))").font(.system(size: 9)).foregroundStyle(ink.opacity(0.5))
            }

            HStack(spacing: 12) {
                kpi("\(trees.count)", "trees mapped")
                kpi("\(analytics.scannedCount(in: season))", "trees scanned")
                kpi("\(Int((rate * 100).rounded()))%", "infected")
                let delta = rate - analytics.infectionRate(in: prev)
                kpi("\(delta >= 0 ? "+" : "")\(Int((delta * 100).rounded())) pts", "vs \(prev.label)", accent: delta > 0 ? Theme.rust : Theme.canopy500)
            }

            VStack(alignment: .leading, spacing: 8) {
                heading("Diseases detected")
                let peak = max(1, Disease.diseases.map { prevalence[$0] ?? 0 }.max() ?? 1)
                VStack(spacing: 6) {
                    ForEach(Disease.diseases) { d in
                        let n = prevalence[d] ?? 0
                        HStack(spacing: 10) {
                            Text(d.name).font(.system(size: 10)).foregroundStyle(ink.opacity(0.8)).frame(width: 110, alignment: .leading)
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(ink.opacity(0.06))
                                    Capsule().fill(d.color.mix(with: ink, by: 0.15))
                                        .frame(width: n == 0 ? 0 : max(4, geo.size.width * CGFloat(n) / CGFloat(peak)))
                                }
                            }
                            .frame(height: 8)
                            Text("\(n)").font(.system(size: 10, weight: .semibold, design: .monospaced)).foregroundStyle(ink).frame(width: 24, alignment: .trailing)
                        }
                    }
                }
            }

            HStack(alignment: .top, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    heading("By block")
                    ForEach(blocks) { b in
                        HStack {
                            Text("\(b.letter) · \(b.name)").font(.system(size: 10, weight: .medium)).foregroundStyle(ink)
                            Spacer()
                            Text(b.variety).font(.system(size: 9)).foregroundStyle(ink.opacity(0.5))
                            Text(analytics.blockRate(b.letter, in: season).map { "\(Int(($0 * 100).rounded()))%" } ?? "—")
                                .font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundStyle(ink).frame(width: 34, alignment: .trailing)
                        }
                        Divider().overlay(ink.opacity(0.1))
                    }
                }
                VStack(alignment: .leading, spacing: 8) {
                    heading("Chronic trees")
                    if chronic.isEmpty { Text("None").font(.system(size: 10)).foregroundStyle(ink.opacity(0.5)) }
                    ForEach(Array(chronic)) { c in
                        HStack {
                            Text(c.code).font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundStyle(ink)
                            Spacer()
                            Text("\(c.dominant.shortName) · \(c.infectedSeasons) seasons").font(.system(size: 9)).foregroundStyle(ink.opacity(0.6))
                        }
                        Divider().overlay(ink.opacity(0.1))
                    }
                }
            }

            HStack(alignment: .top, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    heading("Applied this season")
                    if applied.isEmpty { Text("None recorded").font(.system(size: 10)).foregroundStyle(ink.opacity(0.5)) }
                    ForEach(applied.prefix(6)) { t in
                        Text("• \(t.title) — \(t.targetLabel)").font(.system(size: 9.5)).foregroundStyle(ink.opacity(0.8)).lineLimit(1)
                    }
                }
                VStack(alignment: .leading, spacing: 6) {
                    heading("Coming up")
                    ForEach(Array(planned)) { t in
                        Text("• \(t.scheduledDate.formatted(.dateTime.month(.abbreviated).day())): \(t.title)").font(.system(size: 9.5)).foregroundStyle(ink.opacity(0.8)).lineLimit(1)
                    }
                }
            }

            Spacer(minLength: 0)
            Text("Diagnoses from an on-device ResNet-50 (Acharla & Kandasamy, IEEE SusTech; 85% test accuracy). Treat as decision support and confirm with your extension service. Follow all product labels.")
                .font(.system(size: 8)).foregroundStyle(ink.opacity(0.5))
        }
        .padding(40)
        .background(paper)
    }

    private func heading(_ s: String) -> some View {
        Text(s.uppercased()).font(.system(size: 9, weight: .bold)).tracking(1.2).foregroundStyle(ink.opacity(0.55))
    }

    private func kpi(_ value: String, _ label: String, accent: Color? = nil) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.system(size: 22, weight: .semibold, design: .serif)).foregroundStyle(accent ?? ink)
            Text(label).font(.system(size: 9)).foregroundStyle(ink.opacity(0.55))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10).fill(ink.opacity(0.05)))
    }
}
