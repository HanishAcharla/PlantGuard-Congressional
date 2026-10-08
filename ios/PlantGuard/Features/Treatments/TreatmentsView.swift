import SwiftData
import SwiftUI
import UserNotifications

@MainActor
enum Reminders {
    static func schedule(_ t: TreatmentRecord) async {
        let center = UNUserNotificationCenter.current()
        guard (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) == true else { return }
        let content = UNMutableNotificationContent()
        content.title = t.title
        content.body = "\(t.targetLabel) · \(t.disease.name)"
        content.sound = .default
        var when = Calendar.current.dateComponents([.year, .month, .day], from: t.scheduledDate)
        when.hour = 8
        let id = t.id.uuidString
        try? await center.add(UNNotificationRequest(identifier: id, content: content,
                                                    trigger: UNCalendarNotificationTrigger(dateMatching: when, repeats: false)))
        t.notificationID = id
    }

    static func cancel(_ t: TreatmentRecord) {
        guard let id = t.notificationID else { return }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
        t.notificationID = nil
    }
}

struct TreatmentsView: View {
    private enum Tab: String, CaseIterable { case upcoming = "Upcoming", log = "Log" }

    @Environment(\.modelContext) private var context
    @Query(sort: \TreatmentRecord.scheduledDate) private var treatments: [TreatmentRecord]
    @State private var tab: Tab = .upcoming
    @State private var adding = false

    var body: some View {
        let planned = treatments.filter { $0.status == .planned }
        let done = treatments.filter { $0.status != .planned }.reversed()
        let thisSeason = done.filter { Season(date: $0.scheduledDate) == Season.current }

        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 22) {
                    StatBlock(value: "\(planned.count)", label: "planned", color: Theme.amber)
                    StatBlock(value: "\(thisSeason.count)", label: "applied this season", color: Theme.sage)
                    StatBlock(value: "\(done.count)", label: "on record")
                    Spacer()
                }
                categoryMix(Array(done))
                Picker("", selection: $tab) { ForEach(Tab.allCases, id: \.self) { Text($0.rawValue) } }
                    .pickerStyle(.segmented)

                if tab == .upcoming {
                    if planned.isEmpty {
                        GlassCard { EmptyStateView(symbol: "calendar.badge.plus", title: "Nothing planned", message: "Add a spray or sanitation task to get reminders.") }
                    }
                    ForEach(planned) { t in
                        TreatmentRow(treatment: t)
                            .contextMenu { actions(for: t) }
                    }
                    if !planned.isEmpty {
                        Text("Long-press a task to mark it applied, skip it, or delete it.")
                            .font(.system(size: 11)).foregroundStyle(Theme.textTertiary)
                    }
                } else {
                    ForEach(Array(done.prefix(80))) { t in
                        TreatmentRow(treatment: t).contextMenu { actions(for: t) }
                    }
                }

                Text(DiseaseLibrary.labelNotice).font(.system(size: 11)).foregroundStyle(Theme.textTertiary).padding(.top, 8)
            }
            .padding(.horizontal, 20)
        }
        .tabBarSafeArea()
        .screenBackground()
        .navigationTitle("Treatments")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { adding = true } label: { Image(systemName: "plus.circle.fill").font(.system(size: 20)) }
            }
        }
        .sheet(isPresented: $adding) { AddTreatmentView() }
    }

    @ViewBuilder
    private func actions(for t: TreatmentRecord) -> some View {
        if t.status != .applied {
            Button { t.status = .applied; t.appliedDate = .now; Reminders.cancel(t); Haptics.success() } label: { Label("Mark applied", systemImage: "checkmark.circle") }
        }
        if t.status == .planned {
            Button { t.status = .skipped; Reminders.cancel(t) } label: { Label("Skip", systemImage: "forward") }
        }
        Button(role: .destructive) { Reminders.cancel(t); context.delete(t) } label: { Label("Delete", systemImage: "trash") }
    }

    private func categoryMix(_ done: [TreatmentRecord]) -> some View {
        let total = max(1, done.count)
        return GlassCard(padding: 14, cornerRadius: 20) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Program mix").kickerStyle(Theme.textTertiary)
                GeometryReader { geo in
                    HStack(spacing: 2) {
                        ForEach(TreatmentCategory.allCases) { c in
                            let n = done.filter { $0.category == c }.count
                            if n > 0 {
                                Rectangle().fill(color(c)).frame(width: geo.size.width * CGFloat(n) / CGFloat(total))
                            }
                        }
                    }
                    .clipShape(Capsule())
                }
                .frame(height: 10)
                LazyVGrid(columns: [GridItem(.flexible(), alignment: .leading), GridItem(.flexible(), alignment: .leading)], spacing: 6) {
                    ForEach(TreatmentCategory.allCases) { c in
                        HStack(spacing: 5) {
                            Circle().fill(color(c)).frame(width: 7, height: 7)
                            Text(c.label.components(separatedBy: " ").first ?? "").font(.system(size: 11)).foregroundStyle(Theme.textSecondary)
                            Text("\(done.filter { $0.category == c }.count)").font(.mono(11)).foregroundStyle(Theme.textTertiary)
                        }
                    }
                }
            }
        }
    }

    private func color(_ c: TreatmentCategory) -> Color {
        switch c {
        case .cultural: Theme.sage
        case .organic: Theme.mint
        case .conventional: Color(hex: 0x6FA8DC)
        case .monitoring: Theme.amber
        }
    }
}

struct AddTreatmentView: View {
    private enum Target: Hashable { case orchard, block(String), tree }

    var treeCode: String?
    var disease: Disease?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query private var orchards: [Orchard]
    @Query(sort: \Tree.code) private var trees: [Tree]

    @State private var selectedDisease: Disease = .scab
    @State private var title = ""
    @State private var category: TreatmentCategory = .conventional
    @State private var target: Target = .orchard
    @State private var pickedTree: String?
    @State private var pickingTree = false
    @State private var date = Date.now
    @State private var appliedNow = false
    @State private var remind = true
    @State private var notes = ""

    init(treeCode: String? = nil, disease: Disease? = nil) {
        self.treeCode = treeCode
        self.disease = disease
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Disease") {
                    Picker("Targeting", selection: $selectedDisease) {
                        ForEach(Disease.allCases) { Text($0.name).tag($0) }
                    }
                }
                .listRowBackground(Theme.parchment.opacity(0.06))
                Section {
                    ForEach(DiseaseLibrary.profile(selectedDisease).options) { option in
                        Button {
                            Haptics.tap()
                            title = option.title
                            category = option.category
                            notes = option.timing
                        } label: {
                            HStack {
                                Image(systemName: option.category.symbol).foregroundStyle(Theme.sage).frame(width: 22)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(option.title).foregroundStyle(Theme.textPrimary)
                                    Text(option.timing).font(.system(size: 11)).foregroundStyle(Theme.textTertiary)
                                }
                                Spacer()
                                if title == option.title { Image(systemName: "checkmark").foregroundStyle(Theme.rustLight) }
                            }
                        }
                    }
                } header: {
                    Text("Recommended")
                } footer: {
                    Text("Pick one to fill in the details, or write your own below.")
                }
                .listRowBackground(Theme.parchment.opacity(0.06))
                Section("Task") {
                    TextField("What will you do?", text: $title)
                    Picker("Type", selection: $category) {
                        ForEach(TreatmentCategory.allCases) { Text($0.label).tag($0) }
                    }
                    Picker("Where", selection: $target) {
                        Text("Whole orchard").tag(Target.orchard)
                        ForEach(orchards.first?.blocks.sorted { $0.letter < $1.letter } ?? []) { b in
                            Text("Block \(b.letter) · \(b.name)").tag(Target.block(b.letter))
                        }
                        Text("One tree").tag(Target.tree)
                    }
                    if target == .tree {
                        Button { pickingTree = true } label: {
                            HStack {
                                Text("Tree").foregroundStyle(Theme.textPrimary)
                                Spacer()
                                Text(pickedTree ?? "Choose…").font(.mono(14)).foregroundStyle(Theme.sage)
                            }
                        }
                    }
                }
                .listRowBackground(Theme.parchment.opacity(0.06))
                Section("When") {
                    Toggle("Already applied", isOn: $appliedNow)
                    DatePicker(appliedNow ? "Applied on" : "Scheduled for", selection: $date, displayedComponents: .date)
                    if !appliedNow { Toggle("Remind me at 8 AM", isOn: $remind) }
                }
                .listRowBackground(Theme.parchment.opacity(0.06))
                Section("Notes") {
                    TextField("Rate, product, weather…", text: $notes, axis: .vertical).lineLimit(2...5)
                }
                .listRowBackground(Theme.parchment.opacity(0.06))
            }
            .scrollContentBackground(.hidden)
            .background(AppBackground())
            .navigationTitle("Plan treatment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.disabled(title.isEmpty || (target == .tree && pickedTree == nil))
                }
            }
            .sheet(isPresented: $pickingTree) { TreePickerView(selection: $pickedTree) }
            .onAppear {
                if let disease { selectedDisease = disease.isDisease ? disease : .scab }
                if let treeCode { target = .tree; pickedTree = treeCode }
            }
        }
    }

    private func save() {
        var blockName: String?
        if case .block(let letter) = target { blockName = "Block \(letter)" }
        let t = TreatmentRecord(title: title, disease: selectedDisease, category: category, scheduledDate: date,
                                status: appliedNow ? .applied : .planned, notes: notes, blockName: blockName)
        context.insert(t)
        if target == .tree, let code = pickedTree { t.tree = trees.first { $0.code == code } }
        if !appliedNow && remind {
            Task { await Reminders.schedule(t) }
        }
        Haptics.success()
        dismiss()
    }
}
