import Foundation

struct TreatmentOption: Identifiable, Hashable {
    var id: String { title }
    let title: String
    let category: TreatmentCategory
    let detail: String
    let timing: String
    var frac: String? = nil
    /// Seasons when this action is actually useful.
    let seasons: [SeasonKind]
}

struct DiseaseProfile {
    let disease: Disease
    let summary: String
    let symptoms: [String]
    let conditions: String
    let lifecycle: String
    let peakSeasons: [SeasonKind]
    let options: [TreatmentOption]
}

/// General guidance distilled from standard university-extension apple disease recommendations.
enum DiseaseLibrary {
    static let labelNotice = "Always read and follow the product label — the label is the law. Check which products are registered where you farm, rotate FRAC groups, and confirm with your local extension service before spraying."

    static func profile(_ d: Disease) -> DiseaseProfile { profiles[d]! }

    private static let profiles: [Disease: DiseaseProfile] = [
        .scab: DiseaseProfile(
            disease: .scab,
            summary: "The most widespread apple disease. The fungus overwinters in fallen leaves and fires spores into the canopy during spring rains.",
            symptoms: [
                "Olive-green, velvety spots on the upper leaf surface",
                "Spots darken, turn corky, and leaves may yellow and drop early",
                "Dark, scabby, cracked lesions on fruit",
            ],
            conditions: "Cool, wet springs. An infection needs leaves to stay wet ~9 hours at 63–75 °F, and much longer when it's cooler (the Mills table).",
            lifecycle: "Ascospores from last year's leaf litter infect from green tip until about a month after petal fall. Those lesions then produce conidia that cause secondary infections through summer whenever it's wet.",
            peakSeasons: [.spring, .summer],
            options: [
                TreatmentOption(title: "Shred fallen leaves", category: .cultural,
                                detail: "Flail-mow or shred leaf litter after leaf drop (rake it out from under the tree row first). Removes most of next spring's spore supply.",
                                timing: "After leaf drop, or before green tip", seasons: [.fall, .winter, .spring]),
                TreatmentOption(title: "5% urea on leaf litter", category: .cultural,
                                detail: "Speeds leaf breakdown and suppresses ascospore production for the coming spring.",
                                timing: "Post-harvest, just before or after leaf drop", seasons: [.fall]),
                TreatmentOption(title: "Prune for airflow", category: .cultural,
                                detail: "Open the canopy so leaves dry faster after rain and sprays reach the interior.",
                                timing: "Dormant pruning", seasons: [.winter]),
                TreatmentOption(title: "Copper at green tip", category: .organic,
                                detail: "Early-season protectant. Switch products by tight cluster to avoid fruit russeting.",
                                timing: "Silver tip to green tip", frac: "M1", seasons: [.spring]),
                TreatmentOption(title: "Sulfur or lime sulfur", category: .organic,
                                detail: "Protectant; lime sulfur adds limited after-infection activity. Avoid in high heat or within ~2 weeks of oil sprays.",
                                timing: "Before forecast wetting periods", frac: "M2", seasons: [.spring, .summer]),
                TreatmentOption(title: "Captan or mancozeb protectant", category: .conventional,
                                detail: "Keep a protectant on before infection periods; renew after ~1–2 in. of rain or a flush of new growth.",
                                timing: "Green tip through summer covers", frac: "M4 / M3", seasons: [.spring, .summer]),
                TreatmentOption(title: "DMI or SDHI + protectant", category: .conventional,
                                detail: "Systemic options with 48–96 h of after-infection activity. Always pair with a protectant and never apply the same group back-to-back.",
                                timing: "Within 2–4 days after an infection period", frac: "FRAC 3 / 7", seasons: [.spring]),
                TreatmentOption(title: "Spray by forecast, not calendar", category: .monitoring,
                                detail: "Use the Mills-table forecast to protect ahead of real infection periods and skip sprays when wetting is too short.",
                                timing: "Primary season", seasons: [.spring, .summer]),
            ]),
        .rust: DiseaseProfile(
            disease: .rust,
            summary: "A fungus that alternates between apple and eastern red cedar or juniper. Galls on nearby cedars release spores during spring rains.",
            symptoms: [
                "Bright yellow-orange spots on the upper leaf surface, often red-bordered",
                "Tiny black dots in the centre of each spot",
                "Tube-like cups on the leaf underside by mid-summer",
            ],
            conditions: "Warm spring rains (50–75 °F) with 4+ hours of leaf wetness while the orange, jelly-like galls on junipers are active.",
            lifecycle: "Spores from juniper galls infect apple from pink until ~30 days after petal fall. Apple lesions send spores back to junipers in late summer — rust never spreads apple-to-apple.",
            peakSeasons: [.spring, .summer],
            options: [
                TreatmentOption(title: "Remove nearby cedars and galls", category: .cultural,
                                detail: "Remove eastern red cedar within a few hundred yards where practical, or cut galls off junipers in late winter.",
                                timing: "Late winter", seasons: [.winter, .spring]),
                TreatmentOption(title: "Choose resistant cultivars", category: .cultural,
                                detail: "Gala, Fuji and Golden Delicious are highly susceptible — favour rust-resistant varieties for replants.",
                                timing: "When planning replants", seasons: [.fall, .winter]),
                TreatmentOption(title: "DMI fungicide", category: .conventional,
                                detail: "Myclobutanil or difenoconazole are highly effective and have some after-infection activity.",
                                timing: "Pink through second cover", frac: "FRAC 3", seasons: [.spring]),
                TreatmentOption(title: "Mancozeb protectant", category: .conventional,
                                detail: "Solid protectant when on the leaf before spore release.",
                                timing: "Pink through petal fall", frac: "M3", seasons: [.spring]),
                TreatmentOption(title: "Sulfur (partial control)", category: .organic,
                                detail: "Only partial control — tighten intervals while galls are releasing spores.",
                                timing: "During spring rains", frac: "M2", seasons: [.spring]),
                TreatmentOption(title: "Watch the cedar galls", category: .monitoring,
                                detail: "When galls swell into orange gelatinous horns after rain, apple infection risk is high.",
                                timing: "Spring rains", seasons: [.spring]),
            ]),
        .powderyMildew: DiseaseProfile(
            disease: .powderyMildew,
            summary: "Overwinters inside infected buds and covers new leaves and shoots with a white, felt-like growth.",
            symptoms: [
                "White to grey powdery patches, usually on the leaf underside first",
                "Leaves crinkle, curl lengthwise and turn brittle",
                "Stunted, silvery shoots; net-like russet on fruit",
            ],
            conditions: "Warm days (65–80 °F) with high humidity. Unlike most fungi it doesn't need free water — heavy rain actually suppresses it.",
            lifecycle: "Mycelium survives winter in buds. Infected buds break at tight cluster and release spores that spread in dry, humid weather until terminal shoots stop growing.",
            peakSeasons: [.spring, .summer],
            options: [
                TreatmentOption(title: "Prune out flag shoots", category: .cultural,
                                detail: "Remove silvery, stunted shoots during dormant pruning and again at tight cluster — that's where the fungus overwinters.",
                                timing: "Dormant season and early spring", seasons: [.winter, .spring, .fall]),
                TreatmentOption(title: "Moderate nitrogen", category: .cultural,
                                detail: "Excess nitrogen drives soft, susceptible shoot growth.",
                                timing: "Season-long", seasons: [.spring, .summer]),
                TreatmentOption(title: "Sulfur", category: .organic,
                                detail: "Very effective protectant. Don't apply above ~85 °F or near oil sprays; some varieties are sulfur-sensitive.",
                                timing: "Tight cluster to terminal bud set", frac: "M2", seasons: [.spring, .summer]),
                TreatmentOption(title: "Potassium bicarbonate or oil", category: .organic,
                                detail: "Contact eradicants that knock back existing colonies — thorough coverage is essential.",
                                timing: "When colonies are visible", seasons: [.summer]),
                TreatmentOption(title: "DMI / SDHI / QoI rotation", category: .conventional,
                                detail: "Rotate FRAC groups from tight cluster until shoot growth stops — mildew develops resistance quickly.",
                                timing: "Tight cluster to terminal bud set", frac: "FRAC 3 / 7 / 11", seasons: [.spring, .summer]),
                TreatmentOption(title: "Scout terminal shoots", category: .monitoring,
                                detail: "Check ~100 shoots weekly; act when roughly 1 in 10 shows mildew.",
                                timing: "Weekly in season", seasons: [.spring, .summer]),
            ]),
        .frogEyeLeafSpot: DiseaseProfile(
            disease: .frogEyeLeafSpot,
            summary: "Caused by the black rot fungus, which lives in dead wood, cankers and mummified fruit — sanitation matters as much as spraying.",
            symptoms: [
                "Small purple specks that enlarge into round spots",
                "Tan centres ringed in purple — the classic 'frog eye'",
                "Heavily spotted leaves yellow and drop; black rot on fruit",
            ],
            conditions: "Warm (70–85 °F), wet weather from petal fall through summer.",
            lifecycle: "Spores splash from cankers, dead limbs and mummified fruit during rain. Leaf spots appear 1–3 weeks after petal fall and continue through summer.",
            peakSeasons: [.summer, .fall],
            options: [
                TreatmentOption(title: "Remove dead wood and mummies", category: .cultural,
                                detail: "Prune out cankers, dead limbs and fire-blight strikes; pull mummified fruit off trees and the ground.",
                                timing: "Dormant pruning", seasons: [.winter, .spring, .fall]),
                TreatmentOption(title: "Clear pruning debris", category: .cultural,
                                detail: "Brush piles left in the orchard keep releasing spores — chip or remove them.",
                                timing: "After pruning", seasons: [.winter, .spring]),
                TreatmentOption(title: "Captan cover sprays", category: .conventional,
                                detail: "The standard protectant against frog eye and black rot from petal fall onward.",
                                timing: "Petal fall through summer", frac: "M4", seasons: [.spring, .summer]),
                TreatmentOption(title: "QoI fungicide", category: .conventional,
                                detail: "Strobilurin products also control black rot — stay within label limits and rotate.",
                                timing: "Petal fall through summer", frac: "FRAC 11", seasons: [.spring, .summer]),
                TreatmentOption(title: "Sanitation-first organic plan", category: .organic,
                                detail: "Sulfur and copper give limited control; removing inoculum sources is the core of an organic program.",
                                timing: "Year-round", seasons: [.winter, .spring, .summer, .fall]),
                TreatmentOption(title: "Check for new cankers", category: .monitoring,
                                detail: "After hail or storms, inspect limbs for fresh wounds and cankers that can seed infections.",
                                timing: "After storms", seasons: [.summer, .fall]),
            ]),
        .complex: DiseaseProfile(
            disease: .complex,
            summary: "The leaf shows more than one disease at once. In the training data these mixed cases were merged into a single class.",
            symptoms: [
                "Two or more lesion types on the same leaf",
                "Often scab with frog eye, or rust with another disease",
                "Fast yellowing and leaf drop",
            ],
            conditions: "Usually a sign of high disease pressure, with several pathogens active at once — common after long wet spells.",
            lifecycle: "Each component disease follows its own cycle; target the most damaging one first.",
            peakSeasons: [.spring, .summer, .fall],
            options: [
                TreatmentOption(title: "Confirm what's on the leaf", category: .monitoring,
                                detail: "Rescan several leaves from the same tree, or send a sample to an extension diagnostic lab to name each pathogen.",
                                timing: "Right away", seasons: [.spring, .summer, .fall]),
                TreatmentOption(title: "Broad-spectrum protectant", category: .conventional,
                                detail: "Captan or mancozeb covers scab, rust and frog eye at once while you confirm.",
                                timing: "Before the next rain", frac: "M4 / M3", seasons: [.spring, .summer]),
                TreatmentOption(title: "Sanitation sweep", category: .cultural,
                                detail: "Leaf litter, dead wood and mummies feed several diseases — clearing them pays off for all of them.",
                                timing: "Fall and dormant season", seasons: [.fall, .winter, .spring]),
                TreatmentOption(title: "Sulfur plus sanitation", category: .organic,
                                detail: "Sulfur covers scab and mildew; pair it with thorough sanitation for frog eye.",
                                timing: "In season", frac: "M2", seasons: [.spring, .summer]),
            ]),
        .healthy: DiseaseProfile(
            disease: .healthy,
            summary: "No disease detected on this leaf. Keep scouting — most infections only show symptoms 9–17 days after they happen.",
            symptoms: ["Even green colour", "No spots, coatings or curling", "Smooth leaf surface"],
            conditions: "Healthy today. Risk depends on the weather ahead — check the forecast for infection periods.",
            lifecycle: "",
            peakSeasons: [],
            options: [
                TreatmentOption(title: "Keep a scouting rhythm", category: .monitoring,
                                detail: "Scan ~10 leaves per tree weekly in spring and every two weeks in summer.",
                                timing: "In season", seasons: [.spring, .summer, .fall]),
                TreatmentOption(title: "Preventive sanitation", category: .cultural,
                                detail: "Fall leaf shredding and dormant pruning lower next year's disease pressure for every pathogen.",
                                timing: "Fall and winter", seasons: [.fall, .winter]),
                TreatmentOption(title: "Forecast-timed protection", category: .conventional,
                                detail: "During primary scab season, protect ahead of predicted infection periods rather than after symptoms appear.",
                                timing: "Spring", seasons: [.spring]),
            ]),
    ]
}

enum Urgency: Int, Comparable {
    case routine, soon, urgent
    static func < (a: Urgency, b: Urgency) -> Bool { a.rawValue < b.rawValue }

    var label: String {
        switch self {
        case .routine: "Routine"
        case .soon: "Act this week"
        case .urgent: "Act now"
        }
    }
}

struct CarePlan {
    let disease: Disease
    let urgency: Urgency
    let headline: String
    let notes: [String]
    let now: [TreatmentOption]
    let prevention: [TreatmentOption]
}

/// Turns a diagnosis into a season-aware plan: what's worth doing right now vs. what to set up
/// for next season, adjusted for model confidence and the tree's history.
enum CarePlanner {
    static func plan(for disease: Disease, confidence: Double, date: Date = .now, priorSeasonsWithDisease: Int = 0) -> CarePlan {
        let season = Season(date: date).kind
        let profile = DiseaseLibrary.profile(disease)
        let now = profile.options.filter { $0.seasons.contains(season) }
        let later = profile.options.filter { !$0.seasons.contains(season) }

        var notes: [String] = []
        if confidence < 0.55 && disease.isDisease {
            notes.append("The model is only \(Int(confidence * 100))% sure. Rescan a few leaves from different sides of the tree before spending on sprays.")
        }
        if priorSeasonsWithDisease >= 2 && disease.isDisease {
            notes.append("This tree had \(disease.shortName.lowercased()) in \(priorSeasonsWithDisease) earlier seasons — treat it as a chronic site: prioritise sanitation and consider a resistant variety if you replant.")
        }

        let (urgency, headline) = framing(disease, season: season, confidence: confidence)
        return CarePlan(disease: disease, urgency: urgency, headline: headline, notes: notes,
                        now: now.isEmpty ? Array(profile.options.prefix(2)) : now, prevention: later)
    }

    private static func framing(_ d: Disease, season: SeasonKind, confidence: Double) -> (Urgency, String) {
        let unsure = confidence < 0.55
        switch (d, season) {
        case (.healthy, _): return (.routine, "Looks healthy — keep scouting on schedule")
        case (.scab, .spring): return (unsure ? .soon : .urgent, "Primary scab season — protect before the next rain")
        case (.scab, .summer): return (.soon, "Secondary scab spreads in wet spells — keep covers on")
        case (.scab, _): return (.soon, "Spore season is over — cut next spring's inoculum now")
        case (.rust, .spring): return (unsure ? .soon : .urgent, "Cedar galls are releasing spores — protect from pink to second cover")
        case (.rust, _): return (.routine, "Rust can't spread apple-to-apple — plan junipers and spring protection")
        case (.powderyMildew, .spring), (.powderyMildew, .summer): return (unsure ? .soon : .urgent, "Knock mildew back while shoots are still growing")
        case (.powderyMildew, _): return (.soon, "Mark infected shoots now and prune them out this winter")
        case (.frogEyeLeafSpot, .summer): return (.soon, "Keep captan covers on and clear spore sources")
        case (.frogEyeLeafSpot, _): return (.soon, "Remove dead wood and mummies to stop the spore supply")
        case (.complex, _): return (.urgent, "Several diseases at once — confirm, then cover broadly")
        }
    }
}
