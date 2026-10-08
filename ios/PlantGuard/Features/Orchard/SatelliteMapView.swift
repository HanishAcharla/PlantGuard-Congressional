import MapKit
import SwiftUI

/// The same orchard laid over Apple Maps satellite imagery at its real coordinates.
struct SatelliteMapView: View {
    let orchard: Orchard
    let trees: [Tree]
    let status: [String: Disease]
    let hidden: Set<Disease>
    let selectedCode: String?
    let route: [Tree]
    @Binding var position: MapCameraPosition
    var editing: Bool
    var onSelect: (String?) -> Void
    var onCameraChange: (MapCamera) -> Void

    private func coordinate(_ t: Tree) -> CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: t.latitude, longitude: t.longitude)
    }

    var body: some View {
        MapReader { proxy in
            Map(position: $position, interactionModes: .all) {
                ForEach(orchard.blocks) { block in
                    MapPolygon(coordinates: OrchardGeometry.blockCorners(block, in: orchard))
                        .foregroundStyle(Theme.canopy950.opacity(editing ? 0.35 : 0.15))
                        .stroke(editing ? Theme.rustLight : Theme.parchment.opacity(0.6), lineWidth: editing ? 2 : 1.2)
                }
                ForEach(orchard.blocks) { block in
                    Annotation("", coordinate: OrchardGeometry.coordinate(x: block.originX, y: block.originY + block.length + 2.5, in: orchard), anchor: .bottomLeading) {
                        Text("\(block.letter) · \(block.name)")
                            .font(.system(size: 11, weight: .bold))
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .foregroundStyle(Theme.parchment)
                            .background(Capsule().fill(Theme.canopy950.opacity(0.75)))
                    }
                }
                ForEach(trees) { tree in
                    let d = status[tree.code]
                    let dimmed = d.map { hidden.contains($0) } ?? false
                    MapCircle(center: coordinate(tree), radius: 1.25)
                        .foregroundStyle((d.map { $0 == .healthy ? Color(hex: 0x6CC48A) : $0.color } ?? Color(hex: 0x9FB3A6)).opacity(dimmed ? 0.15 : 0.92))
                        .stroke(.black.opacity(0.45), lineWidth: 0.7)
                }
                if !route.isEmpty {
                    MapPolyline(coordinates: [OrchardGeometry.coordinate(x: -3, y: -3, in: orchard)] + route.map(coordinate))
                        .stroke(Theme.rustLight, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round, dash: [7, 5]))
                }
                if let code = selectedCode, let tree = trees.first(where: { $0.code == code }) {
                    Annotation(tree.code, coordinate: coordinate(tree)) {
                        PulsingMarker(color: status[code]?.color ?? Theme.parchment, size: 34)
                    }
                }
                UserAnnotation()
            }
            .mapStyle(.imagery(elevation: .realistic))
            // Keep the orchard (and Apple's map controls) clear of the header and bottom panels.
            .safeAreaPadding(EdgeInsets(top: 200, leading: 0, bottom: 300, trailing: 0))
            .mapControls {
                MapCompass()
                MapScaleView()
                MapUserLocationButton()
            }
            .onMapCameraChange(frequency: .onEnd) { context in onCameraChange(context.camera) }
            .onTapGesture { point in
                guard !editing, let c = proxy.convert(point, from: .local) else { return }
                let hit = trees.min { OrchardGeometry.distance(coordinate($0), c) < OrchardGeometry.distance(coordinate($1), c) }
                if let hit, OrchardGeometry.distance(coordinate(hit), c) < 4 {
                    Haptics.tap()
                    onSelect(hit.code)
                } else {
                    onSelect(nil)
                }
            }
        }
    }
}
