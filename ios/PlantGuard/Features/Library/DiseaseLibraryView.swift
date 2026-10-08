import SwiftData
import SwiftUI

struct DiseaseLibraryView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("The six conditions the model knows, what causes them, and what to do about them.")
                    .font(.system(size: 14)).foregroundStyle(Theme.textSecondary)
                ForEach(Disease.diseases + [.healthy]) { d in
                    NavigationLink(value: Route.disease(d)) { LibraryCard(disease: d) }
                        .buttonStyle(PressableStyle())
                }
            }
            .padding(.horizontal, 20)
        }
        .tabBarSafeArea()
        .screenBackground()
        .navigationTitle("Disease library")
    }
}

private struct LibraryCard: View {
    let disease: Disease

    var body: some View {
        let profile = DiseaseLibrary.profile(disease)
        HStack(spacing: 16) {
            ZStack {
                Circle().fill(disease.color.opacity(0.2)).blur(radius: 14)
                LeafArt(disease: disease, seed: 11)
            }
            .frame(width: 92, height: 92)
            VStack(alignment: .leading, spacing: 6) {
                Text(disease.name).font(.display(20)).foregroundStyle(Theme.textPrimary)
                Text(disease.pathogen).font(.system(size: 12).italic()).foregroundStyle(Theme.textTertiary)
                Text(profile.summary).font(.system(size: 13)).foregroundStyle(Theme.textSecondary).lineLimit(2)
                HStack(spacing: 6) {
                    ForEach(profile.peakSeasons, id: \.self) { k in
                        Label(k.name, systemImage: k.symbol).font(.system(size: 10, weight: .semibold))
                            .padding(.horizontal, 7).padding(.vertical, 3)
                            .foregroundStyle(disease.color.mix(with: Theme.parchment, by: 0.4))
                            .background(Capsule().fill(disease.color.opacity(0.14)))
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(.ultraThinMaterial))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(disease.color.opacity(0.22), lineWidth: 1))
    }
}

struct DiseaseDetailView: View {
    let disease: Disease
    @Query private var trees: [Tree]
    @Query private var scans: [Scan]
    @State private var planning = false

    var body: some View {
        let profile = DiseaseLibrary.profile(disease)
        let analytics = OrchardAnalytics(trees: trees, scans: scans)
        let current = trees.filter { analytics.currentStatus(of: $0.code, lookback: 1) == disease }.count
        let detections = scans.filter { $0.disease == disease }.count

        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ZStack {
                    RadialGradient(colors: [disease.color.opacity(0.45), .clear], center: .center, startRadius: 10, endRadius: 180)
                    LeafArt(disease: disease, seed: 23, tilt: false).frame(width: 220, height: 220)
                }
                .frame(height: 240)
                .frame(maxWidth: .infinity)

                VStack(alignment: .leading, spacing: 6) {
                    Text(disease.pathogen).font(.system(size: 14).italic()).foregroundStyle(Theme.textSecondary)
                    Text(disease.name).font(.display(34)).foregroundStyle(Theme.textPrimary)
                    Text(profile.summary).font(.system(size: 15)).foregroundStyle(Theme.textSecondary)
                }

                if disease.isDisease {
                    HStack(spacing: 22) {
                        StatBlock(value: "\(current)", label: "trees this season", color: current > 0 ? Theme.rustLight : Theme.textPrimary)
                        StatBlock(value: "\(detections)", label: "detections on record")
                        Spacer()
                    }
                }

                section("Symptoms") {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(profile.symptoms, id: \.self) { s in
                            Label { Text(s).foregroundStyle(Theme.textPrimary.opacity(0.85)) } icon: {
                                Image(systemName: "circle.fill").font(.system(size: 6)).foregroundStyle(disease.color)
                            }
                            .font(.system(size: 14))
                        }
                    }
                }
                section("Favoured by") { Text(profile.conditions).font(.system(size: 14)).foregroundStyle(Theme.textPrimary.opacity(0.85)) }
                if !profile.lifecycle.isEmpty {
                    section("Life cycle") { Text(profile.lifecycle).font(.system(size: 14)).foregroundStyle(Theme.textPrimary.opacity(0.85)) }
                }

                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(kicker: "Management", title: "Treatment options")
                    ForEach(TreatmentCategory.allCases) { c in
                        let options = profile.options.filter { $0.category == c }
                        if !options.isEmpty {
                            GlassCard(padding: 16, cornerRadius: 22) {
                                VStack(alignment: .leading, spacing: 12) {
                                    Label(c.label, systemImage: c.symbol).kickerStyle(Theme.sage)
                                    ForEach(options) { TreatmentOptionRow(option: $0) }
                                }
                            }
                        }
                    }
                    Text(DiseaseLibrary.labelNotice).font(.system(size: 11)).foregroundStyle(Theme.textTertiary)
                }

                Button { planning = true } label: { Label("Plan a treatment", systemImage: "calendar.badge.plus") }
                    .buttonStyle(PrimaryButtonStyle())
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .tabBarSafeArea()
        .screenBackground()
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $planning) { AddTreatmentView(disease: disease) }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        GlassCard(padding: 16, cornerRadius: 22) {
            VStack(alignment: .leading, spacing: 10) {
                Text(title).kickerStyle(Theme.textTertiary)
                content()
            }
        }
    }
}
