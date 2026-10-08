import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Query private var orchards: [Orchard]
    @Query private var scans: [Scan]
    @AppStorage("growerName") private var growerName = ""
    @AppStorage("climateID") private var climateID = ClimateProfile.appleHill.id
    @AppStorage("hasOnboarded") private var hasOnboarded = true
    @State private var confirm: Action?

    private enum Action: Identifiable {
        case reloadDemo, eraseHistory
        var id: Int { hashValue }
    }

    var body: some View {
        Form {
            Section("You") {
                TextField("Your name", text: $growerName)
            }
            .listRowBackground(Theme.parchment.opacity(0.06))
            if let orchard = orchards.first {
                Section("Orchard") {
                    TextField("Name", text: Binding(get: { orchard.name }, set: { orchard.name = $0 }))
                    TextField("Region", text: Binding(get: { orchard.region }, set: { orchard.region = $0 }))
                    Picker("Forecast climate", selection: $climateID) {
                        ForEach(ClimateProfile.all) { Text($0.name).tag($0.id) }
                    }
                    LabeledContent("Coordinates", value: String(format: "%.5f, %.5f", orchard.anchorLatitude, orchard.anchorLongitude))
                }
                .listRowBackground(Theme.parchment.opacity(0.06))
            }
            Section {
                Button("Reload demo orchard") { confirm = .reloadDemo }
                Button("Erase scan history", role: .destructive) { confirm = .eraseHistory }
            } header: {
                Text("Data")
            } footer: {
                Text("\(scans.count) scans stored on this iPhone. Nothing is uploaded.")
            }
            .listRowBackground(Theme.parchment.opacity(0.06))
            Section("Simulator tips") {
                Label("Add leaf photos by dragging image files onto the Simulator window.", systemImage: "photo.badge.plus")
                Label("Pretend you're in the orchard: Features ▸ Location ▸ Custom Location, then enter the coordinates above.", systemImage: "location.fill")
            }
            .listRowBackground(Theme.parchment.opacity(0.06))
            .font(.system(size: 13))
            Section("About") {
                LabeledContent("Model", value: "ResNet-50 · Core ML")
                LabeledContent("Research", value: "Acharla & Kandasamy, IEEE SusTech")
                LabeledContent("Version", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0")
                Button("Replay onboarding") { hasOnboarded = false }
            }
            .listRowBackground(Theme.parchment.opacity(0.06))
        }
        .scrollContentBackground(.hidden)
        .background(AppBackground())
        .tabBarSafeArea()
        .navigationTitle("Settings")
        .confirmationDialog("Are you sure?", isPresented: Binding(get: { confirm != nil }, set: { if !$0 { confirm = nil } }), titleVisibility: .visible, presenting: confirm) { action in
            switch action {
            case .reloadDemo:
                Button("Replace everything with the demo orchard", role: .destructive) { try? DemoSeeder.reset(context, withHistory: true) }
            case .eraseHistory:
                Button("Erase all scans, treatments and notes", role: .destructive) { try? DemoSeeder.reset(context, withHistory: false) }
            }
        } message: { action in
            Text(action == .reloadDemo ? "Your own scans, notes and layout changes will be replaced." : "The orchard is reset to its 254-tree layout with no scans, treatments or notes.")
        }
    }
}
