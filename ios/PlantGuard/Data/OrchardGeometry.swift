import CoreLocation
import Foundation

/// Converts between the orchard's local planting grid (metres east/north of an anchor, before
/// rotation) and real coordinates. Moving or rotating the anchor re-lays every tree on the map.
enum OrchardGeometry {
    static let metresPerDegreeLat = 111_320.0

    static func coordinate(x: Double, y: Double, anchorLat: Double, anchorLon: Double, heading: Double) -> CLLocationCoordinate2D {
        let theta = heading * .pi / 180
        let east = x * cos(theta) + y * sin(theta)
        let north = -x * sin(theta) + y * cos(theta)
        return CLLocationCoordinate2D(
            latitude: anchorLat + north / metresPerDegreeLat,
            longitude: anchorLon + east / (metresPerDegreeLat * cos(anchorLat * .pi / 180)))
    }

    static func coordinate(x: Double, y: Double, in orchard: Orchard) -> CLLocationCoordinate2D {
        coordinate(x: x, y: y, anchorLat: orchard.anchorLatitude, anchorLon: orchard.anchorLongitude, heading: orchard.headingDegrees)
    }

    /// Local metres for a coordinate (inverse of `coordinate`).
    static func local(of c: CLLocationCoordinate2D, in orchard: Orchard) -> (x: Double, y: Double) {
        let north = (c.latitude - orchard.anchorLatitude) * metresPerDegreeLat
        let east = (c.longitude - orchard.anchorLongitude) * metresPerDegreeLat * cos(orchard.anchorLatitude * .pi / 180)
        let theta = orchard.headingDegrees * .pi / 180
        return (east * cos(theta) - north * sin(theta), east * sin(theta) + north * cos(theta))
    }

    static func blockCorners(_ block: OrchardBlock, in orchard: Orchard, margin: Double = 1.2) -> [CLLocationCoordinate2D] {
        let x0 = block.originX - margin, y0 = block.originY - margin
        let x1 = block.originX + block.width + margin, y1 = block.originY + block.length + margin
        return [(x0, y0), (x1, y0), (x1, y1), (x0, y1)].map { coordinate(x: $0.0, y: $0.1, in: orchard) }
    }

    static func relayout(_ orchard: Orchard) {
        for block in orchard.blocks {
            for tree in block.trees {
                let c = coordinate(x: tree.localX, y: tree.localY, in: orchard)
                tree.latitude = c.latitude
                tree.longitude = c.longitude
            }
        }
    }

    static func distance(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> Double {
        CLLocation(latitude: a.latitude, longitude: a.longitude).distance(from: CLLocation(latitude: b.latitude, longitude: b.longitude))
    }

    /// Greedy nearest-neighbour walking order through `stops`, starting from `start`.
    static func inspectionRoute(from start: (x: Double, y: Double), stops: [Tree]) -> [Tree] {
        var remaining = stops
        var route: [Tree] = []
        var cur = start
        while !remaining.isEmpty {
            let i = remaining.indices.min { a, b in
                hypot(remaining[a].localX - cur.x, remaining[a].localY - cur.y) < hypot(remaining[b].localX - cur.x, remaining[b].localY - cur.y)
            }!
            let next = remaining.remove(at: i)
            route.append(next)
            cur = (next.localX, next.localY)
        }
        return route
    }

    static func routeLength(_ route: [Tree], from start: (x: Double, y: Double)) -> Double {
        var total = 0.0
        var cur = start
        for t in route {
            total += hypot(t.localX - cur.x, t.localY - cur.y)
            cur = (t.localX, t.localY)
        }
        return total
    }
}
