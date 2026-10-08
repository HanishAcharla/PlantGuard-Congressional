import SwiftData
import SwiftUI

struct DatabaseView: View {
    private enum Table: String, CaseIterable, Identifiable {
        case trees = "Trees", scans = "Scans", treatments = "Treatments", notes = "Notes"
        var id: String { rawValue }
        var symbol: String {
            switch self {
            case .trees: "tree.fill"
            case .scans: "viewfinder"
            case .treatments: "cross.vial.fill"
            case .notes: "bubble.left.fill"
            }
        }
    }

    @Environment(\.modelContext) private var context
    @Query private var orchards: [Orchard]
    @Query(sort: \Tree.code) private var trees: [Tree]
    @Query(sort: \Scan.date, order: .reverse) private var scans: [Scan]
    @Query(sort: \TreatmentRecord.scheduledDate, order: .reverse) private var treatments: [TreatmentRecord]
    @Query(sort: \CommunityNote.createdAt, order: .reverse) private var notes: [CommunityNote]
    @State private var table: Table = .trees
    @State private var search = ""
    @State private var exportURL: URL?
    @State private var backupURL: URL?
    private let pageSize = 150

    var body: some View {
        List {
            Section {
                overview
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                schema
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
            }

            Section {
                Picker("Table", selection: $table) {
                    ForEach(Table.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))

                HStack(spacing: 10) {
                    if let exportURL {
                        ShareLink(item: exportURL) {
                            Label("Export \(table.rawValue.lowercased()) CSV", systemImage: "tablecells")
                                .font(.system(size: 13, weight: .semibold))
                                .frame(maxWidth: .infinity).padding(.vertical, 10)
                                .background(Capsule().fill(Theme.parchment.opacity(0.08)))
                        }
                    }
                    if let backupURL {
                        ShareLink(item: backupURL) {
                            Label("Full backup", systemImage: "externaldrive.fill")
                                .font(.system(size: 13, weight: .semibold))
                                .frame(maxWidth: .infinity).padding(.vertical, 10)
                                .background(Capsule().fill(Theme.parchment.opacity(0.08)))
                        }
                    }
                }
                .foregroundStyle(Theme.textPrimary)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 8, trailing: 0))
            }

            Section {
                rows
            } header: {
                Text("\(count(of: table)) records\(count(of: table) > pageSize && search.isEmpty ? " · showing \(pageSize)" : "")")
                    .font(.system(size: 12)).foregroundStyle(Theme.textTertiary)
            }
            .listRowBackground(Theme.parchment.opacity(0.05))
        }
        .listStyle(.insetGrouped)
        .searchable(text: $search, prompt: "Search \(table.rawValue.lowercased())")
        .tabBarSafeArea()
        .screenBackground()
        .navigationTitle("Database")
        .task(id: table) { exportURL = makeExport() }
        .task { backupURL = Exporter.jsonBackup(orchard: orchards.first, trees: trees, scans: scans, treatments: treatments, notes: notes) }
    }

    private var overview: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
            ForEach(Table.allCases) { t in
                Button {
                    Haptics.tap()
                    withAnimation(.snappy) { table = t }
                } label: {
                    HStack(spacing: 12) {
                        IconTile(symbol: t.symbol, color: table == t ? Theme.rust : Theme.sage, size: 34)
                        VStack(alignment: .leading, spacing: 0) {
                            Text("\(count(of: t))").font(.display(22)).foregroundStyle(Theme.textPrimary).contentTransition(.numericText())
                            Text(t.rawValue).font(.system(size: 12)).foregroundStyle(Theme.textTertiary)
                        }
                        Spacer()
                    }
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.ultraThinMaterial))
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(table == t ? Theme.rust.opacity(0.5) : Theme.hairline, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var schema: some View {
        GlassCard(padding: 14, cornerRadius: 20) {
            VStack(alignment: .leading, spacing: 10) {
                Text("On-device SwiftData store").kickerStyle(Theme.textTertiary)
                HStack(spacing: 6) {
                    schemaNode("Orchard", 1)
                    arrow
                    schemaNode("Blocks", orchards.first?.blocks.count ?? 0)
                    arrow
                    schemaNode("Trees", trees.count)
                }
                HStack(spacing: 6) {
                    Image(systemName: "arrow.turn.down.right").font(.system(size: 10, weight: .bold)).foregroundStyle(Theme.textTertiary)
                        .padding(.leading, 18)
                    schemaNode("Scans", scans.count)
                    schemaNode("Treatments", treatments.count)
                }
                HStack(spacing: 6) {
                    schemaNode("Notes", notes.count)
                    arrow
                    schemaNode("Comments", notes.reduce(0) { $0 + $1.comments.count })
                }
                Text("\(scans.filter { $0.imageData != nil }.count) photos stored · everything stays on this iPhone")
                    .font(.system(size: 11)).foregroundStyle(Theme.textTertiary)
            }
        }
    }

    private func schemaNode(_ name: String, _ n: Int) -> some View {
        HStack(spacing: 5) {
            Text(name).font(.system(size: 11, weight: .semibold))
            Text("\(n)").font(.mono(10)).foregroundStyle(Theme.textTertiary)
        }
        .padding(.horizontal, 9).padding(.vertical, 5)
        .foregroundStyle(Theme.textPrimary)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Theme.parchment.opacity(0.08)))
    }

    private var arrow: some View {
        Image(systemName: "arrow.right").font(.system(size: 9, weight: .bold)).foregroundStyle(Theme.textTertiary)
    }

    @ViewBuilder
    private var rows: some View {
        switch table {
        case .trees:
            ForEach(limited(trees.filter { search.isEmpty || $0.code.localizedCaseInsensitiveContains(search) || $0.variety.localizedCaseInsensitiveContains(search) })) { t in
                NavigationLink(value: Route.tree(t.code)) {
                    HStack(spacing: 10) {
                        Circle().fill(t.latestScan?.disease.color ?? Theme.parchment.opacity(0.2)).frame(width: 8, height: 8)
                        Text(t.code).font(.mono(14, weight: .semibold)).foregroundStyle(Theme.textPrimary)
                        Text(t.variety).font(.system(size: 12)).foregroundStyle(Theme.textTertiary)
                        Spacer()
                        if t.isFlagged { Image(systemName: "flag.fill").font(.system(size: 10)).foregroundStyle(Theme.rust) }
                        Text("\(t.scans.count) scans").font(.system(size: 11)).foregroundStyle(Theme.textTertiary)
                    }
                }
            }
        case .scans:
            ForEach(limited(scans.filter { search.isEmpty || ($0.tree?.code.localizedCaseInsensitiveContains(search) ?? false) || $0.disease.name.localizedCaseInsensitiveContains(search) })) { s in
                NavigationLink(value: Route.scan(s.id)) {
                    HStack(spacing: 10) {
                        Circle().fill(s.disease.color).frame(width: 8, height: 8)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(s.disease.name).font(.system(size: 14, weight: .medium)).foregroundStyle(Theme.textPrimary)
                            Text("\(s.tree?.code ?? "—") · \(s.date.formatted(date: .abbreviated, time: .omitted))").font(.system(size: 11)).foregroundStyle(Theme.textTertiary)
                        }
                        Spacer()
                        Text(s.confidence, format: .percent.precision(.fractionLength(0))).font(.mono(12)).foregroundStyle(Theme.textSecondary)
                    }
                }
                .swipeActions { Button("Delete", role: .destructive) { context.delete(s) } }
            }
        case .treatments:
            ForEach(limited(treatments.filter { search.isEmpty || $0.title.localizedCaseInsensitiveContains(search) || $0.targetLabel.localizedCaseInsensitiveContains(search) })) { t in
                HStack(spacing: 10) {
                    Image(systemName: t.category.symbol).font(.system(size: 12)).foregroundStyle(Theme.sage).frame(width: 18)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(t.title).font(.system(size: 14, weight: .medium)).foregroundStyle(Theme.textPrimary).lineLimit(1)
                        Text("\(t.targetLabel) · \(t.scheduledDate.formatted(date: .abbreviated, time: .omitted))").font(.system(size: 11)).foregroundStyle(Theme.textTertiary)
                    }
                    Spacer()
                    Text(t.statusRaw.capitalized).font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(t.status == .applied ? Theme.sage : t.status == .planned ? Theme.amber : Theme.textTertiary)
                }
                .swipeActions { Button("Delete", role: .destructive) { context.delete(t) } }
            }
        case .notes:
            ForEach(limited(notes.filter { search.isEmpty || $0.title.localizedCaseInsensitiveContains(search) || $0.authorName.localizedCaseInsensitiveContains(search) })) { n in
                NavigationLink(value: Route.note(n.id)) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(n.title).font(.system(size: 14, weight: .medium)).foregroundStyle(Theme.textPrimary).lineLimit(1)
                        Text("\(n.authorName) · \(n.upvotes) upvotes · \(n.comments.count) replies").font(.system(size: 11)).foregroundStyle(Theme.textTertiary)
                    }
                }
                .swipeActions { Button("Delete", role: .destructive) { context.delete(n) } }
            }
        }
    }

    private func limited<T>(_ items: [T]) -> [T] { search.isEmpty ? Array(items.prefix(pageSize)) : items }

    private func count(of t: Table) -> Int {
        switch t {
        case .trees: trees.count
        case .scans: scans.count
        case .treatments: treatments.count
        case .notes: notes.count
        }
    }

    private func makeExport() -> URL? {
        switch table {
        case .trees: Exporter.csv(trees: trees)
        case .scans: Exporter.csv(scans: scans)
        case .treatments: Exporter.csv(treatments: treatments)
        case .notes: Exporter.csv(notes: notes)
        }
    }
}
