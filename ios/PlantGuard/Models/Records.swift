import Foundation
import SwiftData

@Model
final class Orchard {
    var name: String
    var region: String
    var anchorLatitude: Double
    var anchorLongitude: Double
    /// Rotation of the planting grid, degrees clockwise from north.
    var headingDegrees: Double
    var createdAt: Date
    @Relationship(deleteRule: .cascade, inverse: \OrchardBlock.orchard) var blocks: [OrchardBlock] = []

    init(name: String, region: String, anchorLatitude: Double, anchorLongitude: Double, headingDegrees: Double = 0) {
        self.name = name
        self.region = region
        self.anchorLatitude = anchorLatitude
        self.anchorLongitude = anchorLongitude
        self.headingDegrees = headingDegrees
        self.createdAt = .now
    }
}

@Model
final class OrchardBlock {
    var name: String
    var letter: String
    var variety: String
    var plantedYear: Int
    var rows: Int
    var treesPerRow: Int
    var rowSpacing: Double
    var treeSpacing: Double
    /// South-west corner of the block in orchard-local metres (x east, y north, before rotation).
    var originX: Double
    var originY: Double
    var orchard: Orchard?
    @Relationship(deleteRule: .cascade, inverse: \Tree.block) var trees: [Tree] = []

    init(name: String, letter: String, variety: String, plantedYear: Int, rows: Int, treesPerRow: Int,
         rowSpacing: Double, treeSpacing: Double, originX: Double, originY: Double) {
        self.name = name
        self.letter = letter
        self.variety = variety
        self.plantedYear = plantedYear
        self.rows = rows
        self.treesPerRow = treesPerRow
        self.rowSpacing = rowSpacing
        self.treeSpacing = treeSpacing
        self.originX = originX
        self.originY = originY
    }

    var width: Double { Double(rows) * rowSpacing }
    var length: Double { Double(treesPerRow) * treeSpacing }
}

@Model
final class Tree {
    @Attribute(.unique) var code: String
    var row: Int
    var position: Int
    var variety: String
    var plantedYear: Int
    /// Orchard-local metres (x east, y north, before rotation) — used by the schematic map.
    var localX: Double
    var localY: Double
    var latitude: Double
    var longitude: Double
    var notes: String
    var isFlagged: Bool
    var createdAt: Date
    var block: OrchardBlock?
    @Relationship(deleteRule: .nullify, inverse: \Scan.tree) var scans: [Scan] = []
    @Relationship(deleteRule: .nullify, inverse: \TreatmentRecord.tree) var treatments: [TreatmentRecord] = []

    init(code: String, row: Int, position: Int, variety: String, plantedYear: Int,
         localX: Double, localY: Double, latitude: Double, longitude: Double) {
        self.code = code
        self.row = row
        self.position = position
        self.variety = variety
        self.plantedYear = plantedYear
        self.localX = localX
        self.localY = localY
        self.latitude = latitude
        self.longitude = longitude
        self.notes = ""
        self.isFlagged = false
        self.createdAt = .now
    }

    var sortedScans: [Scan] { scans.sorted { $0.date > $1.date } }
    var latestScan: Scan? { scans.max { $0.date < $1.date } }
}

@Model
final class Scan {
    var id: UUID
    var date: Date
    @Attribute(.externalStorage) var imageData: Data?
    /// Class probabilities in `Disease.modelOrder`.
    var probabilities: [Double]
    var topDiseaseRaw: String
    var confidence: Double
    var notes: String
    var sourceRaw: String
    /// Seed for the procedural leaf illustration shown when a scan has no photo (seeded survey data).
    var artSeed: Int
    var inferenceMilliseconds: Double
    var tree: Tree?

    init(date: Date, probabilities: [Double], imageData: Data? = nil, source: ScanSource,
         notes: String = "", artSeed: Int = Int.random(in: 0..<1_000_000), inferenceMilliseconds: Double = 0) {
        self.id = UUID()
        self.date = date
        self.imageData = imageData
        self.probabilities = probabilities
        let best = probabilities.indices.max { probabilities[$0] < probabilities[$1] } ?? 2
        self.topDiseaseRaw = Disease.modelOrder[best].rawValue
        self.confidence = probabilities[best]
        self.notes = notes
        self.sourceRaw = source.rawValue
        self.artSeed = artSeed
        self.inferenceMilliseconds = inferenceMilliseconds
    }

    var disease: Disease { Disease(rawValue: topDiseaseRaw) ?? .healthy }
    var source: ScanSource { ScanSource(rawValue: sourceRaw) ?? .library }
    var season: Season { Season(date: date) }

    func probability(of d: Disease) -> Double {
        guard let i = Disease.modelOrder.firstIndex(of: d), i < probabilities.count else { return 0 }
        return probabilities[i]
    }

    var ranked: [(disease: Disease, probability: Double)] {
        Disease.modelOrder.map { ($0, probability(of: $0)) }.sorted { $0.1 > $1.1 }
    }
}

enum TreatmentCategory: String, Codable, CaseIterable, Identifiable {
    case cultural, organic, conventional, monitoring

    var id: String { rawValue }
    var label: String {
        switch self {
        case .cultural: "Cultural"
        case .organic: "Organic / biological"
        case .conventional: "Conventional"
        case .monitoring: "Monitoring"
        }
    }
    var symbol: String {
        switch self {
        case .cultural: "scissors"
        case .organic: "leaf.arrow.triangle.circlepath"
        case .conventional: "drop.fill"
        case .monitoring: "binoculars.fill"
        }
    }
}

enum TreatmentStatus: String, Codable, CaseIterable {
    case planned, applied, skipped
}

@Model
final class TreatmentRecord {
    var id: UUID
    var createdAt: Date
    var scheduledDate: Date
    var appliedDate: Date?
    var diseaseRaw: String
    var title: String
    var categoryRaw: String
    var notes: String
    var statusRaw: String
    /// Set when the treatment covers a whole block rather than one tree.
    var blockName: String?
    var notificationID: String?
    var tree: Tree?

    init(title: String, disease: Disease, category: TreatmentCategory, scheduledDate: Date,
         status: TreatmentStatus = .planned, notes: String = "", blockName: String? = nil) {
        self.id = UUID()
        self.createdAt = .now
        self.title = title
        self.diseaseRaw = disease.rawValue
        self.categoryRaw = category.rawValue
        self.scheduledDate = scheduledDate
        self.statusRaw = status.rawValue
        self.appliedDate = status == .applied ? scheduledDate : nil
        self.notes = notes
        self.blockName = blockName
    }

    var disease: Disease { Disease(rawValue: diseaseRaw) ?? .healthy }
    var category: TreatmentCategory { TreatmentCategory(rawValue: categoryRaw) ?? .cultural }
    var status: TreatmentStatus {
        get { TreatmentStatus(rawValue: statusRaw) ?? .planned }
        set { statusRaw = newValue.rawValue }
    }
    var targetLabel: String { tree?.code ?? blockName ?? "Whole orchard" }
}

@Model
final class CommunityNote {
    var id: UUID
    var authorName: String
    var authorRole: String
    var authorRegion: String
    var avatarHue: Double
    var title: String
    var body: String
    var diseaseRaw: String?
    var tags: [String]
    var createdAt: Date
    var upvotes: Int
    var hasUpvoted: Bool
    var isMine: Bool
    var linkedTreeCode: String?
    @Relationship(deleteRule: .cascade, inverse: \NoteComment.note) var comments: [NoteComment] = []

    init(authorName: String, authorRole: String, authorRegion: String, avatarHue: Double, title: String,
         body: String, disease: Disease?, tags: [String], createdAt: Date, upvotes: Int, isMine: Bool = false) {
        self.id = UUID()
        self.authorName = authorName
        self.authorRole = authorRole
        self.authorRegion = authorRegion
        self.avatarHue = avatarHue
        self.title = title
        self.body = body
        self.diseaseRaw = disease?.rawValue
        self.tags = tags
        self.createdAt = createdAt
        self.upvotes = upvotes
        self.hasUpvoted = false
        self.isMine = isMine
    }

    var disease: Disease? { diseaseRaw.flatMap(Disease.init(rawValue:)) }
    var sortedComments: [NoteComment] { comments.sorted { $0.createdAt < $1.createdAt } }
}

@Model
final class NoteComment {
    var id: UUID
    var authorName: String
    var body: String
    var createdAt: Date
    var isMine: Bool
    var note: CommunityNote?

    init(authorName: String, body: String, createdAt: Date, isMine: Bool = false) {
        self.id = UUID()
        self.authorName = authorName
        self.body = body
        self.createdAt = createdAt
        self.isMine = isMine
    }
}

enum AppSchema {
    static let models: [any PersistentModel.Type] = [
        Orchard.self, OrchardBlock.self, Tree.self, Scan.self, TreatmentRecord.self, CommunityNote.self, NoteComment.self,
    ]
}
