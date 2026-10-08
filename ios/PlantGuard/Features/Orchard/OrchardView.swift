import MapKit
import SwiftData
import SwiftUI

struct OrchardView: View {
    private enum Mode: String, CaseIterable { case blocks = "Blocks", satellite = "Satellite" }

    @Environment(AppRouter.self) private var router
    @Query private var orchards: [Orchard]
    @Query(sort: \Tree.code) private var trees: [Tree]
    @Query private var scans: [Scan]

    @State private var mode: Mode = .blocks
    /// nil = "Now" (each tree's most recent status).
    @State private var seasonIndex: Int?
    @State private var selectedCode: String?
    @State private var hidden: Set<Disease> = []
    @State private var playing = false
    @State private var showRoute = false
    @State private var touring = false
    @State private var tourStop = 0
    @State private var editingLayout = false
    @State private var camera: MapCameraPosition = .automatic
    @State private var cameraCenter: CLLocationCoordinate2D?

    var body: some View {
        let analytics = OrchardAnalytics(trees: trees, scans: scans)
        let season = seasonIndex.flatMap { analytics.seasons.indices.contains($0) ? analytics.seasons[$0] : nil }
        let status = statusMap(analytics, season: season)
        let route = showRoute || touring ? inspectionRoute(status) : []

        ZStack(alignment: .top) {
            if let orchard = orchards.first {
                Group {
                    switch mode {
                    case .blocks:
                        SchematicMapView(orchard: orchard, trees: trees, status: status, hidden: hidden, selectedCode: selectedCode,
                                         route: route,
                                         insets: EdgeInsets(top: 205, leading: 18, bottom: showRoute || selectedCode != nil ? 420 : 290, trailing: 22)) { select($0) }
                            .background(AppBackground())
                            .animation(.spring(response: 0.5, dampingFraction: 0.85), value: showRoute || selectedCode != nil)
                    case .satellite:
                        SatelliteMapView(orchard: orchard, trees: trees, status: status, hidden: hidden, selectedCode: selectedCode,
                                         route: route, position: $camera, editing: editingLayout,
                                         onSelect: { select($0) }, onCameraChange: { cameraCenter = $0.centerCoordinate })
                    }
                }
                .ignoresSafeArea()
                .transition(.opacity)

                if editingLayout {
                    Image(systemName: "plus.viewfinder").font(.system(size: 40, weight: .light)).foregroundStyle(Theme.rustLight)
                        .shadow(color: .black, radius: 4)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .allowsHitTesting(false)
                }

                VStack(spacing: 12) {
                    topBar(orchard)
                    legend(analytics, season: season, status: status)
                    Spacer()
                    if editingLayout {
                        LayoutEditorCard(orchard: orchard, center: cameraCenter) { editingLayout = false }
                    } else {
                        if let code = selectedCode, let tree = trees.first(where: { $0.code == code }) {
                            TreePeekCard(tree: tree, status: status[code], timeline: analytics.timeline(of: code),
                                         streak: analytics.streak(of: code),
                                         tourLabel: touring ? "Stop \(tourStop + 1) of \(route.count)" : nil) {
                                selectedCode = nil
                                touring = false
                            }
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                        if showRoute && !touring && !route.isEmpty {
                            RouteSummary(route: route) { startTour(route, orchard: orchard) }
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                        SeasonScrubber(seasons: analytics.seasons, index: $seasonIndex, playing: $playing, analytics: analytics)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 92)
                .animation(.spring(response: 0.42, dampingFraction: 0.85), value: selectedCode)
                .animation(.spring(response: 0.42, dampingFraction: 0.85), value: showRoute)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            #if DEBUG
            if DebugLaunch.value("-mapMode") == "satellite" { mode = .satellite }
            if ProcessInfo.processInfo.arguments.contains("-route") { showRoute = true }
            #endif
            frameOrchard()
            applyFocus()
        }
        .onChange(of: router.focusTreeCode) { _, _ in applyFocus() }
        .onChange(of: mode) { _, _ in frameOrchard() }
        .task(id: playing) {
            guard playing, !analytics.seasons.isEmpty else { return }
            if seasonIndex == nil { seasonIndex = 0 }
            while playing && !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1.25))
                guard playing else { break }
                withAnimation(.easeInOut(duration: 0.35)) {
                    if let i = seasonIndex, i + 1 < analytics.seasons.count { seasonIndex = i + 1 } else { seasonIndex = nil; playing = false }
                }
                Haptics.soft()
            }
        }
    }

    // MARK: Pieces

    private func topBar(_ orchard: Orchard) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(orchard.name).font(.display(24)).foregroundStyle(Theme.textPrimary)
                Text("\(trees.count) trees · \(orchard.blocks.count) blocks").font(.system(size: 12)).foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            HStack(spacing: 2) {
                ForEach(Mode.allCases, id: \.self) { m in
                    Button {
                        Haptics.tap()
                        withAnimation(.snappy) { mode = m; if m == .blocks { editingLayout = false } }
                    } label: {
                        Text(m.rawValue).font(.system(size: 12, weight: .semibold))
                            .padding(.horizontal, 12).padding(.vertical, 8)
                            .foregroundStyle(mode == m ? Theme.canopy950 : Theme.textSecondary)
                            .background(Capsule().fill(mode == m ? Theme.parchment : .clear))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(3)
            .background(Capsule().fill(.ultraThinMaterial))
            Menu {
                Button { withAnimation { showRoute.toggle() } } label: {
                    Label(showRoute ? "Hide inspection route" : "Plan inspection route", systemImage: "point.topleft.down.to.point.bottomright.curvepath")
                }
                Button { mode = .satellite; startTour(inspectionRoute(currentStatus()), orchard: orchard) } label: {
                    Label("Virtual walkthrough", systemImage: "figure.walk")
                }
                Button { mode = .satellite; editingLayout = true } label: {
                    Label("Align orchard on map", systemImage: "move.3d")
                }
                Button { frameOrchard() } label: { Label("Recenter", systemImage: "scope") }
            } label: {
                Image(systemName: "ellipsis").font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.textPrimary)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(.ultraThinMaterial))
            }
        }
        .padding(.top, 4)
    }

    private func legend(_ analytics: OrchardAnalytics, season: Season?, status: [String: Disease]) -> some View {
        var counts: [Disease: Int] = [:]
        for d in status.values { counts[d, default: 0] += 1 }
        let unscanned = trees.count - status.count
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach([Disease.healthy] + Disease.diseases, id: \.self) { d in
                    let on = !hidden.contains(d)
                    Button {
                        Haptics.tap()
                        withAnimation(.snappy) { if on { hidden.insert(d) } else { hidden.remove(d) } }
                    } label: {
                        HStack(spacing: 6) {
                            Circle().fill(d == .healthy ? Color(hex: 0x5DAF78) : d.color).frame(width: 8, height: 8)
                            Text(d.shortName).font(.system(size: 12, weight: .semibold))
                            Text("\(counts[d] ?? 0)").font(.mono(11)).foregroundStyle(Theme.textTertiary)
                        }
                        .padding(.horizontal, 11).padding(.vertical, 7)
                        .foregroundStyle(on ? Theme.textPrimary : Theme.textTertiary)
                        .background(Capsule().fill(.ultraThinMaterial).opacity(on ? 1 : 0.5))
                        .overlay(Capsule().strokeBorder(on ? d.color.opacity(0.35) : .clear, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
                HStack(spacing: 6) {
                    Circle().fill(Color(hex: 0x3B5446)).frame(width: 8, height: 8)
                    Text("Not scanned \(unscanned)").font(.system(size: 12, weight: .medium))
                }
                .padding(.horizontal, 11).padding(.vertical, 7)
                .foregroundStyle(Theme.textTertiary)
                .background(Capsule().fill(.ultraThinMaterial).opacity(0.6))
            }
        }
        .scrollClipDisabled()
    }

    // MARK: Logic

    private func statusMap(_ analytics: OrchardAnalytics, season: Season?) -> [String: Disease] {
        var out: [String: Disease] = [:]
        for t in trees {
            if let d = season.map({ analytics.status(of: t.code, in: $0) }) ?? analytics.currentStatus(of: t.code) { out[t.code] = d }
        }
        return out
    }

    private func currentStatus() -> [String: Disease] {
        statusMap(OrchardAnalytics(trees: trees, scans: scans), season: nil)
    }

    private func inspectionRoute(_ status: [String: Disease]) -> [Tree] {
        let sick = trees.filter { status[$0.code]?.isDisease == true && !hidden.contains(status[$0.code]!) }
        return OrchardGeometry.inspectionRoute(from: (-3, -3), stops: sick)
    }

    private func select(_ code: String?) {
        withAnimation(.spring(response: 0.4)) { selectedCode = code }
        if code == nil { touring = false }
    }

    private func applyFocus() {
        guard let code = router.focusTreeCode, let tree = trees.first(where: { $0.code == code }) else { return }
        router.focusTreeCode = nil
        seasonIndex = nil
        selectedCode = code
        if mode == .satellite { fly(to: tree, distance: 90) }
    }

    private func frameOrchard() {
        guard let orchard = orchards.first else { return }
        let center = OrchardGeometry.coordinate(x: 30, y: 38, in: orchard)
        withAnimation(.easeInOut(duration: 0.8)) {
            camera = .camera(MapCamera(centerCoordinate: center, distance: 360, heading: orchard.headingDegrees, pitch: 0))
        }
    }

    private func fly(to tree: Tree, distance: Double = 70) {
        guard let orchard = orchards.first else { return }
        withAnimation(.easeInOut(duration: 1.4)) {
            camera = .camera(MapCamera(centerCoordinate: CLLocationCoordinate2D(latitude: tree.latitude, longitude: tree.longitude),
                                       distance: distance, heading: orchard.headingDegrees, pitch: 50))
        }
    }

    private func startTour(_ route: [Tree], orchard: Orchard) {
        guard !route.isEmpty else { return }
        touring = true
        showRoute = true
        seasonIndex = nil
        Task { @MainActor in
            for (i, tree) in route.enumerated() {
                guard touring else { break }
                tourStop = i
                selectedCode = tree.code
                fly(to: tree)
                Haptics.soft()
                try? await Task.sleep(for: .seconds(2.8))
            }
            if touring {
                touring = false
                frameOrchard()
            }
        }
    }
}

private struct SeasonScrubber: View {
    let seasons: [Season]
    @Binding var index: Int?
    @Binding var playing: Bool
    let analytics: OrchardAnalytics

    var body: some View {
        GlassCard(padding: 14, cornerRadius: 24) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(index == nil ? "Latest status" : "Season view").kickerStyle(Theme.sage)
                        Text(index.map { seasons[$0].label } ?? "Now").font(.display(20)).foregroundStyle(Theme.textPrimary)
                            .contentTransition(.numericText())
                    }
                    Spacer()
                    if let i = index {
                        let s = seasons[i]
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(analytics.infectedCount(in: s)) infected").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.rustLight)
                            Text("of \(analytics.scannedCount(in: s)) scanned").font(.system(size: 11)).foregroundStyle(Theme.textTertiary)
                        }
                        .contentTransition(.numericText())
                    }
                    Button {
                        Haptics.tap()
                        playing.toggle()
                    } label: {
                        Image(systemName: playing ? "pause.fill" : "play.fill")
                            .font(.system(size: 15, weight: .bold)).foregroundStyle(.white)
                            .frame(width: 40, height: 40)
                            .background(Circle().fill(Theme.rustGradient))
                            .contentTransition(.symbolEffect(.replace))
                    }
                    .padding(.leading, 6)
                }
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            chip("Now", selected: index == nil, rate: nil) { index = nil }.id(-1)
                            ForEach(Array(seasons.enumerated()), id: \.offset) { i, s in
                                chip(s.shortLabel, selected: index == i, rate: analytics.infectionRate(in: s)) { index = i }.id(i)
                            }
                        }
                    }
                    .onChange(of: index) { _, new in withAnimation { proxy.scrollTo(new ?? -1, anchor: .center) } }
                }
            }
        }
    }

    private func chip(_ label: String, selected: Bool, rate: Double?, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.tap()
            playing = false
            withAnimation(.snappy) { action() }
        } label: {
            VStack(spacing: 4) {
                Text(label).font(.system(size: 11, weight: .bold))
                if let rate {
                    Capsule().fill(Theme.parchment.opacity(0.1)).frame(width: 28, height: 4)
                        .overlay(alignment: .leading) {
                            Capsule().fill(selected ? Theme.canopy950 : Theme.rustLight).frame(width: max(2, 28 * min(1, rate * 2)), height: 4)
                        }
                } else {
                    Image(systemName: "dot.radiowaves.left.and.right").font(.system(size: 8))
                }
            }
            .padding(.horizontal, 10).padding(.vertical, 7)
            .foregroundStyle(selected ? Theme.canopy950 : Theme.textSecondary)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(selected ? Theme.parchment : Theme.parchment.opacity(0.06)))
        }
        .buttonStyle(.plain)
    }
}

private struct TreePeekCard: View {
    let tree: Tree
    let status: Disease?
    let timeline: [(season: Season, disease: Disease?)]
    let streak: Int
    let tourLabel: String?
    var onClose: () -> Void
    @Environment(AppRouter.self) private var router

    var body: some View {
        GlassCard(padding: 14, cornerRadius: 24, tint: status?.color) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    Group {
                        if let scan = tree.latestScan { ScanThumbnail(scan: scan) } else { LeafArt(disease: status ?? .healthy, seed: tree.row * 31 + tree.position) }
                    }
                    .frame(width: 58, height: 58)
                    VStack(alignment: .leading, spacing: 4) {
                        if let tourLabel { Text(tourLabel).kickerStyle() }
                        HStack(spacing: 6) {
                            Text(tree.code).font(.mono(18, weight: .bold)).foregroundStyle(Theme.textPrimary)
                            if tree.isFlagged { Image(systemName: "flag.fill").font(.system(size: 11)).foregroundStyle(Theme.rust) }
                        }
                        Text("\(tree.block?.name ?? "") · \(tree.variety)").font(.system(size: 12)).foregroundStyle(Theme.textTertiary)
                    }
                    Spacer()
                    Button(action: onClose) {
                        Image(systemName: "xmark").font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.textSecondary)
                            .frame(width: 26, height: 26).background(Circle().fill(Theme.parchment.opacity(0.08)))
                    }
                }
                HStack(spacing: 8) {
                    if let status { DiseaseBadge(disease: status, compact: true) } else {
                        Text("Not scanned").font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.textTertiary)
                    }
                    if streak > 1 {
                        Text("\(streak) seasons running").font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.rustLight)
                    }
                }
                SeasonStrip(timeline: timeline, dotSize: 13)
                HStack(spacing: 10) {
                    NavigationLink(value: Route.tree(tree.code)) {
                        Text("Tree history").font(.system(size: 14, weight: .semibold))
                            .frame(maxWidth: .infinity).padding(.vertical, 11)
                            .foregroundStyle(Theme.textPrimary)
                            .background(Capsule().fill(Theme.parchment.opacity(0.08)))
                    }
                    Button { router.startScan(treeCode: tree.code) } label: {
                        Label("Scan", systemImage: "viewfinder").font(.system(size: 14, weight: .semibold))
                            .frame(maxWidth: .infinity).padding(.vertical, 11)
                            .foregroundStyle(.white)
                            .background(Capsule().fill(Theme.rustGradient))
                    }
                }
            }
        }
    }
}

private struct RouteSummary: View {
    let route: [Tree]
    var onWalk: () -> Void

    var body: some View {
        let metres = OrchardGeometry.routeLength(route, from: (-3, -3))
        GlassCard(padding: 14, cornerRadius: 22) {
            HStack(spacing: 12) {
                IconTile(symbol: "point.topleft.down.to.point.bottomright.curvepath", color: Theme.rustLight)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Inspection route").font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.textPrimary)
                    Text("\(route.count) infected trees · \(Int(metres)) m · ~\(max(1, Int(metres / 1.2 / 60 + Double(route.count) * 0.5))) min")
                        .font(.system(size: 12)).foregroundStyle(Theme.textTertiary)
                }
                Spacer()
                Button(action: onWalk) {
                    Label("Walk it", systemImage: "figure.walk").font(.system(size: 13, weight: .semibold))
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .foregroundStyle(.white).background(Capsule().fill(Theme.rustGradient))
                }
            }
        }
    }
}

private struct LayoutEditorCard: View {
    @Bindable var orchard: Orchard
    let center: CLLocationCoordinate2D?
    var onDone: () -> Void
    @Environment(\.modelContext) private var context

    var body: some View {
        GlassCard(padding: 16, cornerRadius: 24) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Align orchard").kickerStyle()
                Text("Pan the map so the crosshair sits where Block C's south-west corner should be, then rotate to match your rows.")
                    .font(.system(size: 13)).foregroundStyle(Theme.textSecondary)
                HStack {
                    Image(systemName: "rotate.right").foregroundStyle(Theme.textTertiary)
                    Slider(value: Binding(get: { orchard.headingDegrees }, set: { orchard.headingDegrees = $0; OrchardGeometry.relayout(orchard) }),
                           in: -90...90, step: 1)
                    Text("\(Int(orchard.headingDegrees))°").font(.mono(12)).foregroundStyle(Theme.textSecondary).frame(width: 40)
                }
                HStack(spacing: 10) {
                    Button("Move here") {
                        guard let center else { return }
                        orchard.anchorLatitude = center.latitude
                        orchard.anchorLongitude = center.longitude
                        OrchardGeometry.relayout(orchard)
                        try? context.save()
                        Haptics.success()
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    Button("Done") {
                        try? context.save()
                        onDone()
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
            }
        }
    }
}
