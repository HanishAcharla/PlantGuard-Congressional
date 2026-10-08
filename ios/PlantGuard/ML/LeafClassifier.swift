import CoreML
import UIKit

struct Classification: Equatable {
    /// Probabilities in `Disease.modelOrder`.
    let probabilities: [Double]
    let milliseconds: Double

    var ranked: [(disease: Disease, probability: Double)] {
        zip(Disease.modelOrder, probabilities).map { ($0, $1) }.sorted { $0.1 > $1.1 }
    }
    var top: Disease { ranked.first?.disease ?? .healthy }
    var confidence: Double { ranked.first?.probability ?? 0 }
    /// Below this the model is effectively guessing between classes.
    var isUncertain: Bool { confidence < 0.55 }
}

enum ClassifierError: LocalizedError {
    case modelMissing, badImage, noOutput

    var errorDescription: String? {
        switch self {
        case .modelMissing: "The disease model isn't bundled with the app."
        case .badImage: "That image couldn't be read."
        case .noOutput: "The model returned no prediction."
        }
    }
}

/// Runs the converted ResNet-50 entirely on device. Preprocessing (BGR + ImageNet mean subtraction)
/// is baked into the Core ML input, so callers pass an ordinary upright image.
actor LeafClassifier {
    static let shared = LeafClassifier()
    static let inputSize = 224

    private var model: MLModel?

    private func loadModel() throws -> MLModel {
        if let model { return model }
        guard let url = Bundle.main.url(forResource: "PlantGuardClassifier", withExtension: "mlmodelc") else {
            throw ClassifierError.modelMissing
        }
        let config = MLModelConfiguration()
        config.computeUnits = .all
        let loaded = try MLModel(contentsOf: url, configuration: config)
        model = loaded
        return loaded
    }

    /// Loads the model and runs one throwaway prediction so the first real scan is fast.
    func warmUp() {
        guard let model = try? loadModel(),
              let buffer = PixelBufferFactory.solid(size: Self.inputSize),
              let input = try? MLDictionaryFeatureProvider(dictionary: ["image": MLFeatureValue(pixelBuffer: buffer)])
        else { return }
        _ = try? model.prediction(from: input)
    }

    func classify(_ image: CGImage) throws -> Classification {
        let model = try loadModel()
        guard let buffer = PixelBufferFactory.make(from: image, size: Self.inputSize) else { throw ClassifierError.badImage }
        let input = try MLDictionaryFeatureProvider(dictionary: ["image": MLFeatureValue(pixelBuffer: buffer)])
        let start = CFAbsoluteTimeGetCurrent()
        let output = try model.prediction(from: input)
        let ms = (CFAbsoluteTimeGetCurrent() - start) * 1000
        return Classification(probabilities: try Self.probabilities(from: output), milliseconds: ms)
    }

    /// Occlusion sensitivity: grey out each cell of a `grid`×`grid` lattice and measure how much the
    /// probability of `target` drops. Returns row-major values in 0…1 (1 = most important region).
    func attentionMap(for image: CGImage, target: Disease, grid: Int = 7) throws -> [Double] {
        let model = try loadModel()
        guard let targetIndex = Disease.modelOrder.firstIndex(of: target),
              let baseBuffer = PixelBufferFactory.make(from: image, size: Self.inputSize)
        else { throw ClassifierError.badImage }

        let baseInput = try MLDictionaryFeatureProvider(dictionary: ["image": MLFeatureValue(pixelBuffer: baseBuffer)])
        let baseline = try Self.probabilities(from: model.prediction(from: baseInput))[targetIndex]

        let cell = CGFloat(Self.inputSize) / CGFloat(grid)
        var providers: [MLFeatureProvider] = []
        for row in 0..<grid {
            for col in 0..<grid {
                // CoreGraphics' origin is bottom-left; row 0 is the top of the image.
                let rect = CGRect(x: CGFloat(col) * cell, y: CGFloat(grid - 1 - row) * cell, width: cell, height: cell)
                guard let buffer = PixelBufferFactory.make(from: image, size: Self.inputSize, occluding: rect) else {
                    throw ClassifierError.badImage
                }
                providers.append(try MLDictionaryFeatureProvider(dictionary: ["image": MLFeatureValue(pixelBuffer: buffer)]))
            }
        }
        let batch = try model.predictions(from: MLArrayBatchProvider(array: providers), options: MLPredictionOptions())
        var drops: [Double] = []
        for i in 0..<batch.count {
            let p = try Self.probabilities(from: batch.features(at: i))[targetIndex]
            drops.append(max(0, baseline - p))
        }
        let peak = drops.max() ?? 0
        return peak > 0 ? drops.map { $0 / peak } : drops
    }

    func benchmark(runs: Int = 12) throws -> [Double] {
        let model = try loadModel()
        guard let buffer = PixelBufferFactory.noise(size: Self.inputSize) else { throw ClassifierError.badImage }
        let input = try MLDictionaryFeatureProvider(dictionary: ["image": MLFeatureValue(pixelBuffer: buffer)])
        _ = try model.prediction(from: input)
        return try (0..<runs).map { _ in
            let start = CFAbsoluteTimeGetCurrent()
            _ = try model.prediction(from: input)
            return (CFAbsoluteTimeGetCurrent() - start) * 1000
        }
    }

    private static func probabilities(from output: MLFeatureProvider) throws -> [Double] {
        for name in output.featureNames {
            if let dict = output.featureValue(for: name)?.dictionaryValue, !dict.isEmpty {
                return Disease.modelOrder.map { dict[AnyHashable($0.rawValue)]?.doubleValue ?? 0 }
            }
        }
        throw ClassifierError.noOutput
    }
}

enum PixelBufferFactory {
    /// ImageNet mean colour — after the model's mean subtraction this is ~zero signal.
    private static let occluderColor = CGColor(srgbRed: 123.68 / 255, green: 116.78 / 255, blue: 103.94 / 255, alpha: 1)

    static func make(from image: CGImage, size: Int, occluding rect: CGRect? = nil) -> CVPixelBuffer? {
        render(size: size) { ctx in
            // Squash to 224×224 without cropping — matches keras `load_img(target_size=…)` used in training.
            ctx.interpolationQuality = .high
            ctx.draw(image, in: CGRect(x: 0, y: 0, width: size, height: size))
            if let rect {
                ctx.setFillColor(occluderColor)
                ctx.fill(rect)
            }
        }
    }

    static func solid(size: Int) -> CVPixelBuffer? {
        render(size: size) { ctx in
            ctx.setFillColor(occluderColor)
            ctx.fill(CGRect(x: 0, y: 0, width: size, height: size))
        }
    }

    static func noise(size: Int) -> CVPixelBuffer? {
        render(size: size) { ctx in
            for y in stride(from: 0, to: size, by: 8) {
                for x in stride(from: 0, to: size, by: 8) {
                    ctx.setFillColor(CGColor(srgbRed: .random(in: 0...1), green: .random(in: 0...1), blue: .random(in: 0...1), alpha: 1))
                    ctx.fill(CGRect(x: x, y: y, width: 8, height: 8))
                }
            }
        }
    }

    private static func render(size: Int, draw: (CGContext) -> Void) -> CVPixelBuffer? {
        var buffer: CVPixelBuffer?
        let attrs = [kCVPixelBufferCGImageCompatibilityKey: true, kCVPixelBufferCGBitmapContextCompatibilityKey: true] as CFDictionary
        guard CVPixelBufferCreate(kCFAllocatorDefault, size, size, kCVPixelFormatType_32BGRA, attrs, &buffer) == kCVReturnSuccess,
              let buffer else { return nil }
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        guard let ctx = CGContext(data: CVPixelBufferGetBaseAddress(buffer), width: size, height: size, bitsPerComponent: 8,
                                  bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
                                  space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)
        else { return nil }
        draw(ctx)
        return buffer
    }
}

extension UIImage {
    /// Redraws the image upright (baking in EXIF orientation) and no larger than `maxDimension`.
    func normalized(maxDimension: CGFloat = 1280) -> UIImage {
        let scale = min(1, maxDimension / max(size.width, size.height))
        let target = CGSize(width: (size.width * scale).rounded(), height: (size.height * scale).rounded())
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: target))
        }
    }
}
