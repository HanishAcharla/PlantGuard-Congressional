import SwiftUI

struct ModelLabView: View {
    @State private var timings: [Double] = []
    @State private var running = false
    @State private var benchmarkError: String?

    // Confusion matrix for the fine-tuned ResNet-50, Fig. 4 of the paper (rows = true, cols = predicted).
    private let matrix: [[Int]] = [
        [125, 35, 2, 6, 19, 16],
        [19, 265, 12, 1, 0, 19],
        [0, 1, 433, 0, 0, 25],
        [1, 1, 5, 81, 0, 2],
        [3, 12, 2, 0, 173, 4],
        [11, 9, 31, 3, 3, 405],
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                hero
                pipeline
                metrics
                confusion
                benchmark
                Text("Research: H. Acharla & V. Kandasamy, \u{201C}Data-Driven Solutions in Agriculture: Machine Learning for Apple Disease Classification,\u{201D} IEEE SusTech. The ConvNeXt-XLarge + MLP model scored higher (90.32% test accuracy) but isn't bundled — the app runs the ResNet-50.")
                    .font(.system(size: 11)).foregroundStyle(Theme.textTertiary)
            }
            .padding(.horizontal, 20)
        }
        .tabBarSafeArea()
        .screenBackground()
        .navigationTitle("Model lab")
    }

    private var hero: some View {
        GlassCard(padding: 20, tint: Color(hex: 0x6A3F8F)) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    IconTile(symbol: "cpu.fill", color: Color(hex: 0xD06A9E), size: 46)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("ResNet-50").font(.display(26)).foregroundStyle(Theme.textPrimary)
                        Text("Fine-tuned on Plant Pathology 2021").font(.system(size: 13)).foregroundStyle(Theme.textSecondary)
                    }
                }
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 12) {
                    spec("Dataset images", "17,826")
                    spec("Classes", "6")
                    spec("Input", "224 × 224 photo")
                    spec("Format", "Core ML · FP16")
                    spec("Size on device", "≈ 45 MB")
                    spec("Runs on", "Neural Engine / GPU")
                }
                Label("Checked against the original Keras model: predictions match within 0.2 percentage points.", systemImage: "checkmark.seal.fill")
                    .font(.system(size: 12)).foregroundStyle(Theme.sage)
            }
        }
    }

    private func spec(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.system(size: 11)).foregroundStyle(Theme.textTertiary)
            Text(value).font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.textPrimary)
        }
    }

    private var pipeline: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("What happens when you scan").kickerStyle(Theme.textTertiary)
                ForEach(Array([
                    ("photo", "Your photo", "Rotated upright and resized to 224 × 224"),
                    ("slider.horizontal.3", "Preprocessing", "RGB → BGR and ImageNet mean subtraction, built into the model"),
                    ("square.stack.3d.down.forward.fill", "ResNet-50", "50 layers with residual connections extract leaf features"),
                    ("chart.bar.fill", "Softmax", "Probabilities for 6 conditions"),
                    ("square.grid.3x3.fill", "Attention map", "49 occluded copies show which regions mattered"),
                ].enumerated()), id: \.offset) { i, step in
                    HStack(alignment: .top, spacing: 12) {
                        ZStack {
                            Circle().fill(Theme.parchment.opacity(0.08)).frame(width: 34, height: 34)
                            Image(systemName: step.0).font(.system(size: 13)).foregroundStyle(Theme.rustLight)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(i + 1). \(step.1)").font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.textPrimary)
                            Text(step.2).font(.system(size: 12)).foregroundStyle(Theme.textSecondary)
                        }
                    }
                }
            }
        }
    }

    private var metrics: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Reported performance").kickerStyle(Theme.textTertiary)
                HStack(spacing: 18) {
                    StatBlock(value: "86.5%", label: "validation acc.")
                    StatBlock(value: "85%", label: "test acc.")
                    StatBlock(value: "0.85", label: "precision")
                    StatBlock(value: "84%", label: "F1")
                }
                VStack(alignment: .leading, spacing: 8) {
                    bar("ConvNeXt-XL + MLP", 0.875, Theme.sage, note: "paper's best · not bundled")
                    bar("ResNet-50", 0.865, Theme.rustLight, note: "running in this app")
                    bar("ConvNeXt-XL + KNN", 0.7941, Theme.amber, note: nil)
                    bar("ConvNeXt-XL + RF", 0.7327, Color(hex: 0x7B8FE0), note: nil)
                }
                Text("Validation accuracy, Table I of the paper.").font(.system(size: 10)).foregroundStyle(Theme.textTertiary)
            }
        }
    }

    private func bar(_ name: String, _ value: Double, _ color: Color, note: String?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(name).font(.system(size: 13, weight: .medium)).foregroundStyle(Theme.textPrimary)
                if let note { Text(note).font(.system(size: 10)).foregroundStyle(Theme.textTertiary) }
                Spacer()
                Text(value, format: .percent.precision(.fractionLength(1))).font(.mono(12)).foregroundStyle(Theme.textSecondary)
            }
            GeometryReader { geo in
                Capsule().fill(color).frame(width: geo.size.width * value / 0.9)
            }
            .frame(height: 6)
        }
    }

    private var confusion: some View {
        let order = Disease.modelOrder
        let peak = Double(matrix.flatMap { $0 }.max() ?? 1)
        return GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Where it gets confused").kickerStyle(Theme.textTertiary)
                Text("Test-set confusion matrix. Rows are the true condition, columns what the model predicted.")
                    .font(.system(size: 12)).foregroundStyle(Theme.textSecondary)
                VStack(spacing: 3) {
                    HStack(spacing: 3) {
                        Color.clear.frame(width: 54, height: 1)
                        ForEach(order) { d in
                            Text(d.shortName.prefix(4)).font(.system(size: 8, weight: .bold)).foregroundStyle(Theme.textTertiary).frame(maxWidth: .infinity)
                        }
                    }
                    ForEach(Array(order.enumerated()), id: \.offset) { r, d in
                        let rowTotal = Double(matrix[r].reduce(0, +))
                        HStack(spacing: 3) {
                            Text(d.shortName).font(.system(size: 9, weight: .semibold)).foregroundStyle(Theme.textSecondary).frame(width: 54, alignment: .leading)
                            ForEach(0..<6, id: \.self) { c in
                                let v = matrix[r][c]
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .fill(Color(hex: 0x1E3527).mix(with: r == c ? Theme.sage : Theme.rust, by: sqrt(Double(v) / peak)))
                                    .overlay(Text("\(v)").font(.system(size: 9, weight: .semibold)).foregroundStyle(.white.opacity(v == 0 ? 0.3 : 0.9)))
                                    .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(r == c ? Theme.parchment.opacity(0.4) : .clear, lineWidth: 1))
                                    .frame(height: 30)
                            }
                            Text("\(Int((Double(matrix[r][r]) / rowTotal * 100).rounded()))%").font(.mono(9)).foregroundStyle(Theme.textTertiary).frame(width: 30)
                        }
                    }
                }
                Text("Right column = recall. Complex and Frog Eye are the hardest — they share lesion types.")
                    .font(.system(size: 11)).foregroundStyle(Theme.textTertiary)
            }
        }
    }

    private var benchmark: some View {
        GlassCard(tint: Theme.rust) {
            VStack(alignment: .leading, spacing: 14) {
                Text("Live benchmark").kickerStyle()
                if timings.isEmpty {
                    Text("Time the model on this device — 12 back-to-back predictions.").font(.system(size: 13)).foregroundStyle(Theme.textSecondary)
                } else {
                    let sorted = timings.sorted()
                    HStack(spacing: 22) {
                        StatBlock(value: "\(Int(sorted[sorted.count / 2].rounded())) ms", label: "median")
                        StatBlock(value: "\(Int(sorted.first!.rounded())) ms", label: "fastest")
                        StatBlock(value: "\(Int((1000 / sorted[sorted.count / 2]).rounded()))", label: "leaves / sec")
                    }
                    HStack(alignment: .bottom, spacing: 4) {
                        ForEach(Array(timings.enumerated()), id: \.offset) { _, t in
                            Capsule().fill(Theme.rustLight).frame(width: 10, height: max(4, 50 * t / (sorted.last ?? 1)))
                        }
                    }
                    .frame(height: 52, alignment: .bottom)
                }
                if let benchmarkError { Text(benchmarkError).font(.system(size: 12)).foregroundStyle(Theme.danger) }
                Button {
                    running = true
                    benchmarkError = nil
                    Task {
                        do { timings = try await LeafClassifier.shared.benchmark() } catch { benchmarkError = error.localizedDescription }
                        running = false
                        Haptics.success()
                    }
                } label: {
                    if running { ProgressView().tint(.white) } else { Label(timings.isEmpty ? "Run benchmark" : "Run again", systemImage: "speedometer") }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(running)
            }
        }
    }
}
