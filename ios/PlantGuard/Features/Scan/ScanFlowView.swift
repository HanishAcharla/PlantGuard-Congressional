import PhotosUI
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct ScanFlowView: View {
    let preselectedTreeCode: String?

    private enum Stage: Equatable { case choose, analyzing, result, saved, failed(String) }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(AppRouter.self) private var router
    @Query private var trees: [Tree]

    @State private var stage: Stage = .choose
    @State private var image: UIImage?
    @State private var source: ScanSource = .library
    @State private var classification: Classification?
    @State private var attention: [Double]?
    @State private var showAttention = false
    @State private var photoItem: PhotosPickerItem?
    @State private var showCamera = false
    @State private var showFiles = false
    @State private var showTreePicker = false
    @State private var treeCode: String?
    @State private var notes = ""
    @State private var savedScanID: UUID?

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground(accent: classification?.top.color ?? Theme.rust)
                switch stage {
                case .choose: chooser.transition(.opacity)
                case .analyzing: AnalyzingView(image: image).transition(.opacity)
                case .result, .saved: result.transition(.move(edge: .bottom).combined(with: .opacity))
                case .failed(let message): failure(message)
                }
            }
            .animation(.spring(response: 0.5, dampingFraction: 0.86), value: stage)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.textPrimary)
                            .frame(width: 34, height: 34).background(Circle().fill(.ultraThinMaterial))
                    }
                }
                ToolbarItem(placement: .principal) {
                    Text(stage == .choose ? "New scan" : stage == .analyzing ? "Analyzing" : "Result")
                        .font(.system(size: 16, weight: .semibold)).foregroundStyle(Theme.textPrimary)
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .navigationBarTitleDisplayMode(.inline)
            .appRoutes()
        }
        .onAppear {
            if treeCode == nil { treeCode = preselectedTreeCode }
            #if DEBUG
            if image == nil, let debugImage = DebugLaunch.scanImage { analyze(debugImage, from: .files) }
            #endif
        }
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self), let ui = UIImage(data: data) {
                    analyze(ui, from: .library)
                }
                photoItem = nil
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            LiveCameraView { analyze($0, from: .camera) }
        }
        .fileImporter(isPresented: $showFiles, allowedContentTypes: [.image]) { result in
            guard case .success(let url) = result else { return }
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            if let data = try? Data(contentsOf: url), let ui = UIImage(data: data) { analyze(ui, from: .files) }
        }
        .sheet(isPresented: $showTreePicker) { TreePickerView(selection: $treeCode) }
    }

    // MARK: Choose

    private var chooser: some View {
        ScrollView {
            VStack(spacing: 26) {
                VStack(spacing: 10) {
                    Text("Photograph one leaf").font(.display(32)).foregroundStyle(Theme.textPrimary)
                    Text("Fill the frame with a single apple leaf. The model runs on this iPhone — the photo never leaves it.")
                        .font(.system(size: 15)).foregroundStyle(Theme.textSecondary).multilineTextAlignment(.center)
                }
                .padding(.top, 8)

                ViewfinderIllustration().frame(height: 250)

                if let code = treeCode {
                    Button { showTreePicker = true } label: {
                        Label("Tagging tree \(code)", systemImage: "tree.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .foregroundStyle(Theme.sage)
                            .background(Capsule().fill(Theme.sage.opacity(0.14)))
                    }
                }

                VStack(spacing: 12) {
                    if LiveCamera.isAvailable {
                        Button { showCamera = true } label: { Label("Open live camera", systemImage: "camera.viewfinder") }
                            .buttonStyle(PrimaryButtonStyle())
                        PhotosPicker(selection: $photoItem, matching: .images) {
                            Label("Choose from Photos", systemImage: "photo.on.rectangle.angled")
                        }
                        .buttonStyle(SecondaryButtonStyle())
                    } else {
                        PhotosPicker(selection: $photoItem, matching: .images) {
                            Label("Choose from Photos", systemImage: "photo.on.rectangle.angled")
                        }
                        .buttonStyle(PrimaryButtonStyle())
                    }
                    Button { showFiles = true } label: { Label("Import from Files", systemImage: "folder.fill") }
                        .buttonStyle(SecondaryButtonStyle())
                }

                HStack(spacing: 10) {
                    TipPill(symbol: "rectangle.dashed", text: "Fill the frame")
                    TipPill(symbol: "sun.max", text: "Even light")
                    TipPill(symbol: "arrow.triangle.2.circlepath", text: "Try the underside")
                }
                if !LiveCamera.isAvailable {
                    Text("No camera on this device — drag leaf photos onto the Simulator window to add them to Photos.")
                        .font(.system(size: 12)).foregroundStyle(Theme.textTertiary).multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 30)
        }
    }

    // MARK: Result

    @ViewBuilder
    private var result: some View {
        if let image, let c = classification {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    photoCard(image)
                    DiagnosisHeader(disease: c.top, confidence: c.confidence)
                    if c.isUncertain { UncertaintyCallout() }
                    ProbabilityList(ranked: c.ranked)
                    CarePlanCard(plan: plan(for: c))
                    NavigationLink(value: Route.disease(c.top)) {
                        HStack {
                            Text("Full guide: \(c.top.name)").font(.system(size: 15, weight: .semibold))
                            Spacer()
                            Image(systemName: "arrow.right")
                        }
                        .foregroundStyle(Theme.rustLight)
                        .padding(.horizontal, 4)
                    }
                    treeCard
                    TextField("Add a note (location on tree, weather…)", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                        .padding(14)
                        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.parchment.opacity(0.06)))
                        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Theme.hairline, lineWidth: 1))
                        .disabled(stage == .saved)
                    actions
                    OnDeviceBadge(milliseconds: c.milliseconds)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
        }
    }

    private func photoCard(_ image: UIImage) -> some View {
        VStack(spacing: 10) {
            ZStack {
                Image(uiImage: image).resizable().scaledToFit()
                if showAttention, let attention {
                    AttentionOverlay(values: attention).transition(.opacity)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).strokeBorder(Theme.parchment.opacity(0.14), lineWidth: 1))
            .frame(maxHeight: 340)
            .frame(maxWidth: .infinity)
            .shadow(color: .black.opacity(0.4), radius: 20, y: 10)

            HStack {
                Button {
                    withAnimation(.easeInOut(duration: 0.35)) { showAttention.toggle() }
                    Haptics.tap()
                } label: {
                    Label(showAttention ? "Hide attention map" : "Where the model looked",
                          systemImage: attention == nil ? "hourglass" : "eye.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .background(Capsule().fill(.ultraThinMaterial))
                }
                .disabled(attention == nil)
                .foregroundStyle(attention == nil ? Theme.textTertiary : Theme.textPrimary)
                Spacer()
                Text(source.label).font(.system(size: 12)).foregroundStyle(Theme.textTertiary)
            }
        }
    }

    private var treeCard: some View {
        Button { if stage != .saved { showTreePicker = true } } label: {
            HStack(spacing: 14) {
                IconTile(symbol: "tree.fill", color: Theme.sage)
                VStack(alignment: .leading, spacing: 2) {
                    Text(treeCode.map { "Tree \($0)" } ?? "Assign to a tree").font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.textPrimary)
                    Text(treeCode == nil ? "Track this leaf across seasons on the orchard map" : treeSubtitle)
                        .font(.system(size: 12)).foregroundStyle(Theme.textTertiary)
                }
                Spacer()
                if stage != .saved { Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.textTertiary) }
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(.ultraThinMaterial))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Theme.hairline, lineWidth: 1))
        }
        .buttonStyle(PressableStyle())
    }

    private var treeSubtitle: String {
        guard let tree = trees.first(where: { $0.code == treeCode }) else { return "" }
        return "\(tree.block?.name ?? "") · \(tree.variety) · \(tree.scans.count) earlier scans"
    }

    @ViewBuilder
    private var actions: some View {
        if stage == .saved {
            VStack(spacing: 12) {
                Label("Saved to history", systemImage: "checkmark.seal.fill")
                    .font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.sage)
                    .frame(maxWidth: .infinity)
                    .transition(.scale.combined(with: .opacity))
                HStack(spacing: 12) {
                    Button("Scan another") { reset() }.buttonStyle(SecondaryButtonStyle())
                    if let code = treeCode {
                        Button("View tree") {
                            dismiss()
                            router.showOnMap(code)
                        }
                        .buttonStyle(PrimaryButtonStyle())
                    } else {
                        Button("Done") { dismiss() }.buttonStyle(PrimaryButtonStyle())
                    }
                }
            }
        } else {
            HStack(spacing: 12) {
                Button("Retake") { reset() }.buttonStyle(SecondaryButtonStyle())
                Button { save() } label: { Label("Save", systemImage: "square.and.arrow.down.fill") }
                    .buttonStyle(PrimaryButtonStyle())
            }
        }
    }

    private func failure(_ message: String) -> some View {
        VStack(spacing: 18) {
            EmptyStateView(symbol: "exclamationmark.triangle", title: "Couldn't analyze that photo", message: message)
            Button("Try another photo") { reset() }.buttonStyle(PrimaryButtonStyle()).padding(.horizontal, 40)
        }
    }

    // MARK: Logic

    private func plan(for c: Classification) -> CarePlan {
        var prior = 0
        if let tree = trees.first(where: { $0.code == treeCode }) {
            let current = Season.current
            prior = Set(tree.scans.filter { $0.disease == c.top && $0.season != current }.map(\.season)).count
        }
        return CarePlanner.plan(for: c.top, confidence: c.confidence, priorSeasonsWithDisease: prior)
    }

    private func analyze(_ raw: UIImage, from source: ScanSource) {
        let img = raw.normalized()
        image = img
        self.source = source
        classification = nil
        attention = nil
        showAttention = false
        stage = .analyzing
        Task {
            let started = Date()
            do {
                guard let cg = img.cgImage else { throw ClassifierError.badImage }
                let c = try await LeafClassifier.shared.classify(cg)
                let elapsed = Date().timeIntervalSince(started)
                if elapsed < 1.8 { try? await Task.sleep(for: .seconds(1.8 - elapsed)) } // let the scan animation land
                classification = c
                stage = .result
                c.top.isDisease ? Haptics.warning() : Haptics.success()
                attention = try? await LeafClassifier.shared.attentionMap(for: cg, target: c.top)
            } catch {
                stage = .failed(error.localizedDescription)
            }
        }
    }

    private func save() {
        guard let image, let c = classification else { return }
        let scan = Scan(date: .now, probabilities: c.probabilities, imageData: image.jpegData(compressionQuality: 0.82),
                        source: source, notes: notes, inferenceMilliseconds: c.milliseconds)
        context.insert(scan)
        if let tree = trees.first(where: { $0.code == treeCode }) { scan.tree = tree }
        try? context.save()
        savedScanID = scan.id
        Haptics.success()
        withAnimation(.spring) { stage = .saved }
    }

    private func reset() {
        image = nil
        classification = nil
        attention = nil
        notes = ""
        stage = .choose
    }
}

private struct TipPill: View {
    let symbol: String
    let text: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: symbol).font(.system(size: 15)).foregroundStyle(Theme.sage)
            Text(text).font(.system(size: 11, weight: .medium)).foregroundStyle(Theme.textSecondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.parchment.opacity(0.05)))
    }
}

private struct ViewfinderIllustration: View {
    @State private var float = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(LinearGradient(colors: [Theme.canopy700.opacity(0.6), Theme.canopy950.opacity(0.6)], startPoint: .top, endPoint: .bottom))
                .frame(width: 230, height: 230)
            LeafArt(disease: .healthy, seed: 4, tilt: false)
                .frame(width: 170, height: 170)
                .opacity(0.9)
                .offset(y: float ? -6 : 6)
                .rotationEffect(.degrees(float ? -4 : 4))
            ScanBrackets(color: Theme.parchment.opacity(0.85), lineWidth: 3).frame(width: 210, height: 210)
        }
        .onAppear { withAnimation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true)) { float = true } }
    }
}

/// Animated "scanning" treatment over the photo while the model runs.
private struct AnalyzingView: View {
    let image: UIImage?
    @State private var sweep = false
    @State private var step = 0
    private let steps = ["Normalizing colour channels", "Running ResNet-50 on the Neural Engine", "Comparing against 6 conditions", "Building your care plan"]

    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            ZStack {
                if let image {
                    Image(uiImage: image).resizable().scaledToFill()
                        .frame(width: 290, height: 290)
                        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 30, style: .continuous)
                                .fill(LinearGradient(colors: [Theme.canopy950.opacity(0.0), Theme.rust.opacity(0.18)], startPoint: .top, endPoint: .bottom))
                        )
                }
                DotGrid().frame(width: 290, height: 290).clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                Rectangle()
                    .fill(LinearGradient(colors: [.clear, Theme.rustLight.opacity(0.35), Theme.rustLight, Theme.rustLight.opacity(0.35), .clear],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(width: 290, height: 46)
                    .blendMode(.plusLighter)
                    .offset(y: sweep ? 140 : -140)
                ScanBrackets().frame(width: 316, height: 316)
            }
            .shadow(color: Theme.rust.opacity(0.35), radius: 30)

            VStack(spacing: 10) {
                Text(steps[step]).font(.system(size: 16, weight: .semibold)).foregroundStyle(Theme.textPrimary)
                    .id(step)
                    .transition(.asymmetric(insertion: .move(edge: .bottom).combined(with: .opacity), removal: .opacity))
                HStack(spacing: 6) {
                    ForEach(0..<steps.count, id: \.self) { i in
                        Capsule().fill(i <= step ? Theme.rustLight : Theme.parchment.opacity(0.15)).frame(width: i == step ? 22 : 8, height: 6)
                    }
                }
            }
            Spacer()
            Spacer()
        }
        .onAppear { withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) { sweep = true } }
        .task {
            while step < steps.count - 1 {
                try? await Task.sleep(for: .milliseconds(450))
                withAnimation(.spring(response: 0.4)) { step += 1 }
            }
        }
    }
}

private struct DotGrid: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 20)) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                let step: CGFloat = 18
                var y: CGFloat = step / 2
                while y < size.height {
                    var x: CGFloat = step / 2
                    while x < size.width {
                        let wave = (sin(Double(x) / 30 + Double(y) / 45 - t * 3) + 1) / 2
                        let r = 1 + 1.4 * wave
                        ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                                 with: .color(Theme.parchment.opacity(0.12 + 0.35 * wave)))
                        x += step
                    }
                    y += step
                }
            }
        }
    }
}
