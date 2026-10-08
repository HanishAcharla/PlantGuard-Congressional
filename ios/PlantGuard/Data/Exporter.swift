import Foundation

/// Writes database tables to CSV / JSON files in the temporary directory for the share sheet.
enum Exporter {
    private static let iso = ISO8601DateFormatter()

    static func csv(trees: [Tree]) -> URL? {
        var rows = ["code,block,variety,planted_year,row,position,latitude,longitude,flagged,scan_count,latest_diagnosis,notes"]
        for t in trees.sorted(by: { $0.code < $1.code }) {
            rows.append([t.code, t.block?.name ?? "", t.variety, "\(t.plantedYear)", "\(t.row)", "\(t.position)",
                         String(format: "%.6f", t.latitude), String(format: "%.6f", t.longitude), t.isFlagged ? "yes" : "no",
                         "\(t.scans.count)", t.latestScan?.disease.name ?? "", t.notes].map(escape).joined(separator: ","))
        }
        return write(rows, name: "plantguard-trees.csv")
    }

    static func csv(scans: [Scan]) -> URL? {
        let header = ["id", "date", "season", "tree", "diagnosis", "confidence", "source", "has_photo", "inference_ms"]
            + Disease.modelOrder.map { "p_\($0.rawValue)" } + ["notes"]
        var rows = [header.joined(separator: ",")]
        for s in scans.sorted(by: { $0.date < $1.date }) {
            let fields = [s.id.uuidString, iso.string(from: s.date), s.season.label, s.tree?.code ?? "", s.disease.name,
                          String(format: "%.4f", s.confidence), s.source.label, s.imageData == nil ? "no" : "yes",
                          String(format: "%.1f", s.inferenceMilliseconds)]
                + s.probabilities.map { String(format: "%.4f", $0) } + [s.notes]
            rows.append(fields.map(escape).joined(separator: ","))
        }
        return write(rows, name: "plantguard-scans.csv")
    }

    static func csv(treatments: [TreatmentRecord]) -> URL? {
        var rows = ["id,scheduled,applied,status,title,category,disease,target,notes"]
        for t in treatments.sorted(by: { $0.scheduledDate < $1.scheduledDate }) {
            rows.append([t.id.uuidString, iso.string(from: t.scheduledDate), t.appliedDate.map(iso.string(from:)) ?? "",
                         t.statusRaw, t.title, t.category.label, t.disease.name, t.targetLabel, t.notes].map(escape).joined(separator: ","))
        }
        return write(rows, name: "plantguard-treatments.csv")
    }

    static func csv(notes: [CommunityNote]) -> URL? {
        var rows = ["id,created,author,role,region,title,disease,tags,upvotes,comments,body"]
        for n in notes.sorted(by: { $0.createdAt > $1.createdAt }) {
            rows.append([n.id.uuidString, iso.string(from: n.createdAt), n.authorName, n.authorRole, n.authorRegion, n.title,
                         n.disease?.name ?? "", n.tags.joined(separator: "; "), "\(n.upvotes)", "\(n.comments.count)", n.body]
                .map(escape).joined(separator: ","))
        }
        return write(rows, name: "plantguard-community.csv")
    }

    static func jsonBackup(orchard: Orchard?, trees: [Tree], scans: [Scan], treatments: [TreatmentRecord], notes: [CommunityNote]) -> URL? {
        struct Backup: Encodable {
            struct T: Encodable { let code, block, variety: String; let lat, lon: Double; let flagged: Bool; let notes: String }
            struct S: Encodable { let id: UUID; let date: Date; let tree: String?; let diagnosis: String; let probabilities: [Double]; let notes: String }
            struct R: Encodable { let title, disease, category, status, target: String; let scheduled: Date; let applied: Date? }
            struct N: Encodable { let author, title, body: String; let created: Date; let upvotes: Int; let comments: [String] }
            let exportedAt: Date
            let orchard: String
            let classes: [String]
            let trees: [T]; let scans: [S]; let treatments: [R]; let notes: [N]
        }
        let backup = Backup(
            exportedAt: .now, orchard: orchard?.name ?? "", classes: Disease.modelOrder.map(\.rawValue),
            trees: trees.map { .init(code: $0.code, block: $0.block?.name ?? "", variety: $0.variety, lat: $0.latitude, lon: $0.longitude, flagged: $0.isFlagged, notes: $0.notes) },
            scans: scans.map { .init(id: $0.id, date: $0.date, tree: $0.tree?.code, diagnosis: $0.topDiseaseRaw, probabilities: $0.probabilities, notes: $0.notes) },
            treatments: treatments.map { .init(title: $0.title, disease: $0.diseaseRaw, category: $0.categoryRaw, status: $0.statusRaw, target: $0.targetLabel, scheduled: $0.scheduledDate, applied: $0.appliedDate) },
            notes: notes.map { .init(author: $0.authorName, title: $0.title, body: $0.body, created: $0.createdAt, upvotes: $0.upvotes, comments: $0.sortedComments.map(\.body)) })
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(backup) else { return nil }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("plantguard-backup.json")
        return (try? data.write(to: url)) != nil ? url : nil
    }

    private static func escape(_ s: String) -> String {
        s.contains(where: { ",\"\n".contains($0) }) ? "\"" + s.replacingOccurrences(of: "\"", with: "\"\"") + "\"" : s
    }

    private static func write(_ rows: [String], name: String) -> URL? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        return (try? rows.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)) != nil ? url : nil
    }
}
