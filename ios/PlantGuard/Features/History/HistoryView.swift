import SwiftData
import SwiftUI

struct HistoryView: View {
    @Query(sort: \Scan.date, order: .reverse) private var scans: [Scan]
    @State private var search = ""
    @State private var disease: Disease?
    @State private var photosOnly = false

    var body: some View {
        let groups = grouped
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18, pinnedViews: [.sectionHeaders]) {
                summary
                filters
                if groups.isEmpty {
                    GlassCard { EmptyStateView(symbol: "clock", title: "No matching scans", message: "Try clearing the filters.") }
                }
                ForEach(groups, id: \.title) { group in
                    Section {
                        GlassCard(padding: 6) {
                            VStack(spacing: 0) {
                                ForEach(group.scans) { scan in
                                    NavigationLink(value: Route.scan(scan.id)) { ScanRow(scan: scan) }
                                        .buttonStyle(PressableStyle())
                                }
                            }
                        }
                    } header: {
                        HStack {
                            Text(group.title).font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.textPrimary)
                            Spacer()
                            Text("\(group.scans.count) scans · \(group.scans.filter { $0.disease.isDisease }.count) diseased")
                                .font(.system(size: 11)).foregroundStyle(Theme.textTertiary)
                        }
                        .padding(.vertical, 8).padding(.horizontal, 4)
                        .background(Theme.canopy950.opacity(0.85).blur(radius: 6).padding(-8))
                    }
                }
            }
            .padding(.horizontal, 20)
        }
        .searchable(text: $search, prompt: "Tree code or note")
        .tabBarSafeArea()
        .screenBackground()
        .navigationTitle("History")
    }

    private var summary: some View {
        let diseased = scans.filter { $0.disease.isDisease }.count
        let photos = scans.filter { $0.imageData != nil }.count
        return HStack(spacing: 12) {
            StatBlock(value: "\(scans.count)", label: "scans")
            Divider().frame(height: 34).overlay(Theme.hairline)
            StatBlock(value: "\(diseased)", label: "diseased", color: Theme.rustLight)
            Divider().frame(height: 34).overlay(Theme.hairline)
            StatBlock(value: "\(photos)", label: "your photos")
            Spacer()
        }
        .padding(.top, 4)
    }

    private var filters: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(title: "Photos only", isOn: photosOnly) { photosOnly.toggle() }
                FilterChip(title: "All", isOn: disease == nil) { disease = nil }
                ForEach([Disease.healthy] + Disease.diseases) { d in
                    FilterChip(title: d.shortName, color: d.color, isOn: disease == d) { disease = disease == d ? nil : d }
                }
            }
        }
        .scrollClipDisabled()
    }

    private var grouped: [(title: String, scans: [Scan])] {
        let filtered = scans.filter { s in
            (disease == nil || s.disease == disease) && (!photosOnly || s.imageData != nil)
                && (search.isEmpty || (s.tree?.code.localizedCaseInsensitiveContains(search) ?? false) || s.notes.localizedCaseInsensitiveContains(search))
        }
        var order: [String] = []
        var buckets: [String: [Scan]] = [:]
        for s in filtered {
            let key = s.date.formatted(.dateTime.month(.wide).year())
            if buckets[key] == nil { order.append(key) }
            buckets[key, default: []].append(s)
        }
        return order.map { ($0, buckets[$0]!) }
    }
}

struct ScanDetailView: View {
    @Bindable var scan: Scan
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var attention: [Double]?
    @State private var showAttention = false
    @State private var confirmDelete = false
    @State private var pickingTree = false
    @State private var treeCode: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                photo
                DiagnosisHeader(disease: scan.disease, confidence: scan.confidence)
                if scan.confidence < 0.55 && scan.disease.isDisease { UncertaintyCallout() }
                ProbabilityList(ranked: scan.ranked)
                let prior = scan.tree.map { t in Set(t.scans.filter { $0.disease == scan.disease && $0.season != scan.season }.map(\.season)).count } ?? 0
                CarePlanCard(plan: CarePlanner.plan(for: scan.disease, confidence: scan.confidence, date: scan.date, priorSeasonsWithDisease: prior), compact: false)

                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        detailRow("Date", scan.date.formatted(date: .long, time: .shortened))
                        detailRow("Season", scan.season.label)
                        detailRow("Source", scan.source.label)
                        if scan.inferenceMilliseconds > 0 { detailRow("Inference", "\(Int(scan.inferenceMilliseconds.rounded())) ms on device") }
                        Button { pickingTree = true } label: {
                            HStack {
                                Text("Tree").font(.system(size: 14)).foregroundStyle(Theme.textTertiary)
                                Spacer()
                                Text(scan.tree?.code ?? "Assign…").font(.mono(14, weight: .semibold)).foregroundStyle(Theme.sage)
                                Image(systemName: "chevron.right").font(.system(size: 11)).foregroundStyle(Theme.textTertiary)
                            }
                        }
                        if !scan.notes.isEmpty { detailRow("Notes", scan.notes) }
                    }
                }

                if let code = scan.tree?.code {
                    NavigationLink(value: Route.tree(code)) {
                        Label("Open tree \(code)", systemImage: "tree.fill")
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
                Button(role: .destructive) { confirmDelete = true } label: { Label("Delete scan", systemImage: "trash") }
                    .font(.system(size: 14)).frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .tabBarSafeArea()
        .screenBackground()
        .navigationTitle(scan.disease.shortName)
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Delete this scan?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                context.delete(scan)
                dismiss()
            }
        }
        .sheet(isPresented: $pickingTree) { TreePickerView(selection: $treeCode) }
        .onChange(of: treeCode) { _, code in
            guard let code else { return }
            let match = try? context.fetch(FetchDescriptor<Tree>(predicate: #Predicate<Tree> { $0.code == code })).first
            scan.tree = match
        }
        .task {
            guard let data = scan.imageData, let image = UIImage(data: data)?.normalized(), let cg = image.cgImage else { return }
            attention = try? await LeafClassifier.shared.attentionMap(for: cg, target: scan.disease)
        }
    }

    @ViewBuilder
    private var photo: some View {
        if let data = scan.imageData, let image = UIImage(data: data) {
            VStack(spacing: 10) {
                ZStack {
                    Image(uiImage: image).resizable().scaledToFit()
                    if showAttention, let attention { AttentionOverlay(values: attention).transition(.opacity) }
                }
                .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                .frame(maxHeight: 340)
                .frame(maxWidth: .infinity)
                if attention != nil {
                    Button {
                        withAnimation { showAttention.toggle() }
                    } label: {
                        Label(showAttention ? "Hide attention map" : "Where the model looked", systemImage: "eye.fill")
                            .font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.textPrimary)
                            .padding(.horizontal, 12).padding(.vertical, 7)
                            .background(Capsule().fill(.ultraThinMaterial))
                    }
                }
            }
        } else {
            ZStack {
                LinearGradient(colors: [scan.disease.color.opacity(0.3), Theme.canopy900], startPoint: .topTrailing, endPoint: .bottomLeading)
                LeafArt(disease: scan.disease, seed: scan.artSeed).padding(24)
                VStack {
                    Spacer()
                    Text("Field survey record · illustration").font(.system(size: 11)).foregroundStyle(Theme.textTertiary).padding(10)
                }
            }
            .frame(height: 260)
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        }
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(label).font(.system(size: 14)).foregroundStyle(Theme.textTertiary)
            Spacer()
            Text(value).font(.system(size: 14, weight: .medium)).foregroundStyle(Theme.textPrimary).multilineTextAlignment(.trailing)
        }
    }
}
