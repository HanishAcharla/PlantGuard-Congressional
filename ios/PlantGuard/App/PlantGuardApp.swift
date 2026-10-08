import SwiftData
import SwiftUI

@main
struct PlantGuardApp: App {
    @State private var router = AppRouter()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(router)
                .preferredColorScheme(.dark)
                .tint(Theme.rust)
        }
        .modelContainer(for: AppSchema.models)
    }
}

enum AppTab: Hashable, CaseIterable {
    case home, orchard, seasons, community

    var title: String {
        switch self {
        case .home: "Home"
        case .orchard: "Orchard"
        case .seasons: "Seasons"
        case .community: "Community"
        }
    }

    var symbol: String {
        switch self {
        case .home: "house.fill"
        case .orchard: "map.fill"
        case .seasons: "calendar.day.timeline.left"
        case .community: "bubble.left.and.text.bubble.right.fill"
        }
    }
}

struct ScanRequest: Identifiable {
    let id = UUID()
    let treeCode: String?
}

@Observable
final class AppRouter {
    var tab: AppTab = .home
    var scanRequest: ScanRequest?
    /// Tree to select when the orchard map next appears.
    var focusTreeCode: String?

    func startScan(treeCode: String? = nil) {
        Haptics.soft()
        scanRequest = ScanRequest(treeCode: treeCode)
    }

    func showOnMap(_ code: String) {
        focusTreeCode = code
        withAnimation(.snappy) { tab = .orchard }
    }
}

enum Route: Hashable {
    case tree(String)
    case scan(UUID)
    case note(UUID)
    case disease(Disease)
    case history, database, treatments, library, forecast, modelLab, report, settings
}

extension View {
    func appRoutes() -> some View {
        navigationDestination(for: Route.self) { route in
            switch route {
            case .tree(let code): TreeRouteView(code: code)
            case .scan(let id): ScanRouteView(id: id)
            case .note(let id): NoteRouteView(id: id)
            case .disease(let d): DiseaseDetailView(disease: d)
            case .history: HistoryView()
            case .database: DatabaseView()
            case .treatments: TreatmentsView()
            case .library: DiseaseLibraryView()
            case .forecast: ForecastView()
            case .modelLab: ModelLabView()
            case .report: SeasonReportView()
            case .settings: SettingsView()
            }
        }
    }
}

struct TreeRouteView: View {
    @Query private var trees: [Tree]

    init(code: String) {
        _trees = Query(filter: #Predicate<Tree> { $0.code == code })
    }

    var body: some View {
        if let tree = trees.first {
            TreeDetailView(tree: tree)
        } else {
            EmptyStateView(symbol: "tree", title: "Tree not found", message: "It may have been removed from the orchard.")
                .screenBackground()
        }
    }
}

struct ScanRouteView: View {
    @Query private var scans: [Scan]

    init(id: UUID) {
        _scans = Query(filter: #Predicate<Scan> { $0.id == id })
    }

    var body: some View {
        if let scan = scans.first {
            ScanDetailView(scan: scan)
        } else {
            EmptyStateView(symbol: "doc.text.magnifyingglass", title: "Scan not found", message: "It may have been deleted.")
                .screenBackground()
        }
    }
}

struct NoteRouteView: View {
    @Query private var notes: [CommunityNote]

    init(id: UUID) {
        _notes = Query(filter: #Predicate<CommunityNote> { $0.id == id })
    }

    var body: some View {
        if let note = notes.first {
            NoteDetailView(note: note)
        } else {
            EmptyStateView(symbol: "bubble.left", title: "Note not found", message: "It may have been deleted.")
                .screenBackground()
        }
    }
}
