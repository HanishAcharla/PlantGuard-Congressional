import SwiftUI

/// A tree's diagnosis season by season: filled dot = scanned (colour = diagnosis), hollow = not scanned.
struct SeasonStrip: View {
    let timeline: [(season: Season, disease: Disease?)]
    var dotSize: CGFloat = 16
    var showsLabels = true

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            GeometryReader { geo in
                let n = max(1, timeline.count)
                let spacing = n > 1 ? (geo.size.width - dotSize) / CGFloat(n - 1) : 0
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.parchment.opacity(0.08)).frame(height: 2).padding(.horizontal, dotSize / 2)
                    ForEach(Array(timeline.enumerated()), id: \.offset) { i, item in
                        Group {
                            if let d = item.disease {
                                Circle().fill(d.color)
                                    .overlay(Circle().strokeBorder(.white.opacity(0.25), lineWidth: 1))
                                    .shadow(color: d.isDisease ? d.color.opacity(0.7) : .clear, radius: 5)
                            } else {
                                Circle().strokeBorder(Theme.parchment.opacity(0.25), lineWidth: 1.5)
                                    .background(Circle().fill(Theme.canopy950))
                            }
                        }
                        .frame(width: dotSize, height: dotSize)
                        .offset(x: CGFloat(i) * spacing)
                    }
                }
                .frame(height: dotSize)
            }
            .frame(height: dotSize)
            if showsLabels, let first = timeline.first, let last = timeline.last {
                HStack {
                    Text(first.season.label)
                    Spacer()
                    Text(last.season.label)
                }
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Theme.textTertiary)
            }
        }
    }
}
