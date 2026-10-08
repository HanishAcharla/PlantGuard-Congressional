import SwiftUI

#if DEBUG
/// Debug-only launch arguments for driving the app from `xcrun simctl launch`:
///   -demo                 seed the demo orchard and skip onboarding
///   -screen <name>        orchard | seasons | community | history | database | treatments | library |
///                         forecast | modelLab | report | settings | tree:<CODE> | disease:<raw> | scan
///   -scanImage <file>     open the scanner on <file> from the app's Documents folder
///   -classifyAll          classify every image in Documents and write classify-results.txt
enum DebugLaunch {
    private static let args = ProcessInfo.processInfo.arguments

    static var seedDemo: Bool { args.contains("-demo") }

    static func value(_ flag: String) -> String? {
        guard let i = args.firstIndex(of: flag), i + 1 < args.count else { return nil }
        return args[i + 1]
    }

    static var scanImage: UIImage? {
        guard let name = value("-scanImage"),
              let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first,
              let data = try? Data(contentsOf: docs.appendingPathComponent(name))
        else { return nil }
        return UIImage(data: data)
    }

    /// `-classifyAll`: runs every image in Documents through the same path as the scanner and
    /// writes `classify-results.txt` next to them, so on-device output can be diffed against Keras/Core ML.
    static func classifyAllIfRequested() async {
        guard args.contains("-classifyAll"),
              let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first,
              let files = try? FileManager.default.contentsOfDirectory(atPath: docs.path)
        else { return }
        var lines: [String] = []
        for name in files.sorted() where name.hasSuffix(".jpg") || name.hasSuffix(".png") {
            guard let data = try? Data(contentsOf: docs.appendingPathComponent(name)),
                  let cg = UIImage(data: data)?.normalized().cgImage,
                  let c = try? await LeafClassifier.shared.classify(cg)
            else { lines.append("\(name)\tERROR"); continue }
            lines.append("\(name)\t\(c.top.rawValue)\t\(String(format: "%.1f", c.confidence * 100))")
        }
        try? lines.joined(separator: "\n").write(to: docs.appendingPathComponent("classify-results.txt"), atomically: true, encoding: .utf8)
    }

    @MainActor
    static func apply(router: AppRouter, homePath: inout NavigationPath) {
        if scanImage != nil { router.scanRequest = ScanRequest(treeCode: value("-tree")); return }
        guard let screen = value("-screen") else { return }
        switch screen {
        case "orchard": router.tab = .orchard
        case "seasons": router.tab = .seasons
        case "community": router.tab = .community
        case "scan": router.startScan()
        case "history": homePath.append(Route.history)
        case "database": homePath.append(Route.database)
        case "treatments": homePath.append(Route.treatments)
        case "library": homePath.append(Route.library)
        case "forecast": homePath.append(Route.forecast)
        case "modelLab": homePath.append(Route.modelLab)
        case "report": homePath.append(Route.report)
        case "settings": homePath.append(Route.settings)
        default:
            if screen.hasPrefix("tree:") { homePath.append(Route.tree(String(screen.dropFirst(5)))) }
            if screen.hasPrefix("disease:"), let d = Disease(rawValue: String(screen.dropFirst(8))) { homePath.append(Route.disease(d)) }
            if screen.hasPrefix("map:") { router.showOnMap(String(screen.dropFirst(4))) }
        }
    }
}
#endif
