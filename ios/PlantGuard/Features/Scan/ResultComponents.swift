import SwiftUI

struct DiagnosisHeader: View {
    let disease: Disease
    let confidence: Double

    var body: some View {
        HStack(alignment: .center, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Diagnosis").kickerStyle(disease.color.mix(with: Theme.parchment, by: 0.3))
                Text(disease.name).font(.display(34)).foregroundStyle(Theme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(disease.pathogen).font(.system(size: 14).italic()).foregroundStyle(Theme.textSecondary)
            }
            Spacer(minLength: 8)
            ZStack {
                ConfidenceRing(value: confidence, color: disease.color, lineWidth: 8)
                VStack(spacing: -2) {
                    Text("\(Int((confidence * 100).rounded()))").font(.display(24)).foregroundStyle(Theme.textPrimary)
                    Text("% sure").font(.system(size: 10)).foregroundStyle(Theme.textTertiary)
                }
            }
            .frame(width: 84, height: 84)
        }
    }
}

struct UncertaintyCallout: View {
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Theme.amber)
            VStack(alignment: .leading, spacing: 4) {
                Text("Low confidence").font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.textPrimary)
                Text("The model is split between conditions. Retake the photo with one leaf filling the frame in even light, or scan a few more leaves from the same tree.")
                    .font(.system(size: 13)).foregroundStyle(Theme.textSecondary)
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.amber.opacity(0.12)))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Theme.amber.opacity(0.3), lineWidth: 1))
    }
}

struct ProbabilityList: View {
    let ranked: [(disease: Disease, probability: Double)]

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("All conditions").kickerStyle(Theme.textTertiary)
                ForEach(Array(ranked.enumerated()), id: \.element.disease) { i, item in
                    ProbabilityBar(disease: item.disease, probability: item.probability, emphasized: i == 0, delay: 0.05 * Double(i))
                }
            }
        }
    }
}

struct CarePlanCard: View {
    let plan: CarePlan
    var compact = true

    var body: some View {
        GlassCard(tint: plan.urgency == .urgent ? Theme.rust : plan.urgency == .soon ? Theme.amber : Theme.canopy500) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Care plan").kickerStyle()
                    Spacer()
                    UrgencyTag(urgency: plan.urgency)
                }
                Text(plan.headline).font(.display(21)).foregroundStyle(Theme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                ForEach(plan.notes, id: \.self) { note in
                    Label {
                        Text(note).font(.system(size: 13)).foregroundStyle(Theme.textSecondary)
                    } icon: {
                        Image(systemName: "info.circle.fill").foregroundStyle(Theme.amber)
                    }
                }
                VStack(spacing: 10) {
                    ForEach(compact ? Array(plan.now.prefix(3)) : plan.now) { option in
                        TreatmentOptionRow(option: option)
                    }
                }
                if !compact && !plan.prevention.isEmpty {
                    Text("Set up for later seasons").kickerStyle(Theme.textTertiary).padding(.top, 6)
                    VStack(spacing: 10) {
                        ForEach(plan.prevention) { TreatmentOptionRow(option: $0) }
                    }
                }
            }
        }
    }
}

struct UrgencyTag: View {
    let urgency: Urgency

    var body: some View {
        let color = urgency == .urgent ? Theme.danger : urgency == .soon ? Theme.amber : Theme.sage
        Text(urgency.label)
            .font(.system(size: 11, weight: .bold))
            .padding(.horizontal, 10).padding(.vertical, 5)
            .foregroundStyle(color)
            .background(Capsule().fill(color.opacity(0.15)))
    }
}

struct TreatmentOptionRow: View {
    let option: TreatmentOption

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            IconTile(symbol: option.category.symbol, color: categoryColor, size: 34)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(option.title).font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.textPrimary)
                    if let frac = option.frac {
                        Text(frac).font(.mono(9, weight: .semibold))
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .foregroundStyle(Theme.textSecondary)
                            .background(Capsule().fill(Theme.parchment.opacity(0.08)))
                    }
                }
                Text(option.detail).font(.system(size: 13)).foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Label(option.timing, systemImage: "clock").font(.system(size: 11, weight: .medium)).foregroundStyle(Theme.textTertiary)
            }
            Spacer(minLength: 0)
        }
    }

    private var categoryColor: Color {
        switch option.category {
        case .cultural: Theme.sage
        case .organic: Theme.mint
        case .conventional: Color(hex: 0x6FA8DC)
        case .monitoring: Theme.amber
        }
    }
}

/// Occlusion-sensitivity heatmap drawn over the photo.
struct AttentionOverlay: View {
    let values: [Double]
    var grid = 7

    var body: some View {
        Canvas { ctx, size in
            let cw = size.width / CGFloat(grid), ch = size.height / CGFloat(grid)
            for r in 0..<grid {
                for c in 0..<grid {
                    let v = values[r * grid + c]
                    guard v > 0.08 else { continue }
                    let rect = CGRect(x: CGFloat(c) * cw, y: CGFloat(r) * ch, width: cw, height: ch).insetBy(dx: -cw * 0.45, dy: -ch * 0.45)
                    let color: Color = v > 0.66 ? Color(hex: 0xFF5A36) : v > 0.33 ? Color(hex: 0xFFB13B) : Color(hex: 0xE7E35A)
                    ctx.fill(Path(ellipseIn: rect),
                             with: .radialGradient(Gradient(colors: [color.opacity(0.9 * v), color.opacity(0)]),
                                                   center: CGPoint(x: rect.midX, y: rect.midY), startRadius: 0, endRadius: rect.width / 2))
                }
            }
        }
        .blur(radius: 8)
        .blendMode(.plusLighter)
        .allowsHitTesting(false)
    }
}

struct OnDeviceBadge: View {
    let milliseconds: Double

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "cpu").font(.system(size: 12))
            Text(milliseconds > 0 ? "Analyzed on this iPhone in \(Int(milliseconds.rounded())) ms · nothing uploaded" : "Analyzed on device · nothing uploaded")
                .font(.system(size: 12))
        }
        .foregroundStyle(Theme.textTertiary)
        .frame(maxWidth: .infinity)
    }
}
