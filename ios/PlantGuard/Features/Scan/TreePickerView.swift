import CoreLocation
import SwiftData
import SwiftUI

/// One-shot location lookup used to find the tree the grower is standing next to.
/// In the Simulator, set Features ▸ Location ▸ Custom Location to the orchard's coordinates.
@Observable
final class LocationProvider: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    var location: CLLocation?
    var denied = false
    var locating = false

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }

    func request() {
        locating = true
        switch manager.authorizationStatus {
        case .notDetermined: manager.requestWhenInUseAuthorization()
        case .denied, .restricted: denied = true; locating = false
        default: manager.requestLocation()
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways: if locating { manager.requestLocation() }
        case .denied, .restricted: denied = true; locating = false
        default: break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        location = locations.last
        locating = false
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        locating = false
    }
}

struct TreePickerView: View {
    @Binding var selection: String?
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Tree.code) private var trees: [Tree]
    @State private var search = ""
    @State private var locator = LocationProvider()

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button { locator.request() } label: {
                        HStack(spacing: 12) {
                            IconTile(symbol: "location.fill", color: Color(hex: 0x6FA8DC), size: 34)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Use the tree I'm standing at").font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.textPrimary)
                                Text(nearestDescription).font(.system(size: 12)).foregroundStyle(Theme.textTertiary)
                            }
                            Spacer()
                            if locator.locating { ProgressView() }
                        }
                    }
                    if let hit = nearest {
                        row(hit.0, detail: "\(Int(hit.1.rounded())) m away")
                    }
                }
                .listRowBackground(Theme.parchment.opacity(0.05))

                let flagged = filtered.filter(\.isFlagged)
                if search.isEmpty && !flagged.isEmpty {
                    Section("Flagged trees") {
                        ForEach(flagged) { row($0, detail: "Flagged") }
                    }
                    .listRowBackground(Theme.parchment.opacity(0.05))
                }

                ForEach(blocks, id: \.self) { letter in
                    Section("Block \(letter)") {
                        ForEach(filtered.filter { $0.code.hasPrefix(letter) }) { row($0, detail: nil) }
                    }
                    .listRowBackground(Theme.parchment.opacity(0.05))
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppBackground())
            .searchable(text: $search, prompt: "Tree code, e.g. B-04-06")
            .navigationTitle("Choose a tree")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                if selection != nil {
                    ToolbarItem(placement: .destructiveAction) { Button("Clear") { selection = nil; dismiss() } }
                }
            }
        }
        .presentationDetents([.large])
    }

    private var filtered: [Tree] {
        search.isEmpty ? trees : trees.filter { $0.code.localizedCaseInsensitiveContains(search) || $0.variety.localizedCaseInsensitiveContains(search) }
    }

    private var blocks: [String] {
        Array(Set(filtered.map { String($0.code.prefix(1)) })).sorted()
    }

    private var nearest: (Tree, Double)? {
        guard let loc = locator.location?.coordinate else { return nil }
        return trees.map { ($0, OrchardGeometry.distance(loc, CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude))) }
            .min { $0.1 < $1.1 }
    }

    private var nearestDescription: String {
        if locator.denied { return "Location access is off — enable it in Settings" }
        if let hit = nearest, hit.1 > 150 { return "You're \(Int(hit.1)) m from the orchard — pick a tree below" }
        return "Finds the closest mapped tree by GPS"
    }

    private func row(_ tree: Tree, detail: String?) -> some View {
        Button {
            Haptics.tap()
            selection = tree.code
            dismiss()
        } label: {
            HStack(spacing: 12) {
                Text(tree.code).font(.mono(15, weight: .semibold)).foregroundStyle(Theme.textPrimary)
                Text(tree.variety).font(.system(size: 13)).foregroundStyle(Theme.textTertiary)
                Spacer()
                if let detail { Text(detail).font(.system(size: 12)).foregroundStyle(Theme.sage) }
                if let d = tree.latestScan?.disease { Circle().fill(d.color).frame(width: 8, height: 8) }
                if selection == tree.code { Image(systemName: "checkmark").foregroundStyle(Theme.rustLight) }
            }
        }
    }
}
