import AVFoundation
import CoreImage
import SwiftUI

/// Back-camera session that classifies the framed square of every ~⅓ s of video while the grower
/// aims, and captures a full-resolution photo for the final analysis.
/// Thread-safety is by confinement: session work runs on `sessionQueue`, frame handling on
/// `videoQueue`, and observable UI state is only mutated on the main actor.
@Observable
final class LiveCamera: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, AVCapturePhotoCaptureDelegate, @unchecked Sendable {
    enum Status { case starting, running, unavailable, denied }

    var status: Status = .starting
    var live: Classification?
    /// 0…1 — how consistently recent frames agree on the same diagnosis.
    var stability: Double = 0
    var torchOn = false
    var zoom: CGFloat = 1
    /// Side of the on-screen scan square as a fraction of the (portrait) video width; set by the view.
    var cropFraction: CGFloat = 0.6

    let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "plantguard.camera.session")
    private let videoQueue = DispatchQueue(label: "plantguard.camera.video")
    private let photoOutput = AVCapturePhotoOutput()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let ciContext = CIContext()
    private var device: AVCaptureDevice?
    private var lastInference = Date.distantPast
    private var busy = false
    private var recent: [Disease] = []
    private var photoContinuation: CheckedContinuation<UIImage?, Never>?

    static var isAvailable: Bool {
        AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) != nil
    }

    @MainActor
    func start() async {
        guard Self.isAvailable else { status = .unavailable; return }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: break
        case .notDetermined:
            guard await AVCaptureDevice.requestAccess(for: .video) else { status = .denied; return }
        default:
            status = .denied
            return
        }
        sessionQueue.async { self.configureAndRun() }
        status = .running
    }

    func stop() {
        sessionQueue.async {
            if self.session.isRunning { self.session.stopRunning() }
        }
    }

    private func configureAndRun() {
        if session.inputs.isEmpty {
            session.beginConfiguration()
            session.sessionPreset = .photo
            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                  let input = try? AVCaptureDeviceInput(device: device), session.canAddInput(input)
            else {
                session.commitConfiguration()
                return
            }
            session.addInput(input)
            self.device = device
            if session.canAddOutput(photoOutput) { session.addOutput(photoOutput) }
            videoOutput.alwaysDiscardsLateVideoFrames = true
            videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
            videoOutput.setSampleBufferDelegate(self, queue: videoQueue)
            if session.canAddOutput(videoOutput) { session.addOutput(videoOutput) }
            for output in [videoOutput as AVCaptureOutput, photoOutput] {
                if let c = output.connection(with: .video), c.isVideoRotationAngleSupported(90) { c.videoRotationAngle = 90 }
            }
            if device.isFocusModeSupported(.continuousAutoFocus) {
                try? device.lockForConfiguration()
                device.focusMode = .continuousAutoFocus
                device.unlockForConfiguration()
            }
            session.commitConfiguration()
        }
        session.startRunning()
    }

    // MARK: Live classification

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard !busy, Date().timeIntervalSince(lastInference) > 0.33, let pixels = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        busy = true
        lastInference = Date()
        let frame = CIImage(cvPixelBuffer: pixels)
        let side = min(frame.extent.width, frame.extent.height) * cropFraction
        let square = CGRect(x: frame.extent.midX - side / 2, y: frame.extent.midY - side / 2, width: side, height: side)
        guard let cg = ciContext.createCGImage(frame, from: square) else {
            busy = false
            return
        }
        Task {
            let result = try? await LeafClassifier.shared.classify(cg)
            await MainActor.run { self.absorb(result) }
            videoQueue.async { self.busy = false }
        }
    }

    @MainActor
    private func absorb(_ result: Classification?) {
        guard let result else { return }
        recent.append(result.top)
        if recent.count > 6 { recent.removeFirst() }
        let agreement = Double(recent.filter { $0 == result.top }.count) / 6
        withAnimation(.snappy(duration: 0.25)) {
            live = result
            stability = result.isUncertain ? agreement * 0.5 : agreement
        }
    }

    // MARK: Photo

    @MainActor
    func capturePhoto() async -> UIImage? {
        await withCheckedContinuation { continuation in
            photoContinuation = continuation
            sessionQueue.async {
                let settings = AVCapturePhotoSettings()
                settings.flashMode = .off
                self.photoOutput.capturePhoto(with: settings, delegate: self)
            }
        }
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        let image = photo.fileDataRepresentation().flatMap(UIImage.init(data:))?.normalized(maxDimension: 2400)
        let fraction = cropFraction
        DispatchQueue.main.async {
            self.photoContinuation?.resume(returning: image?.centerSquare(fraction: fraction))
            self.photoContinuation = nil
        }
    }

    // MARK: Controls

    func toggleTorch() {
        guard let device, device.hasTorch else { return }
        try? device.lockForConfiguration()
        device.torchMode = torchOn ? .off : .on
        device.unlockForConfiguration()
        torchOn.toggle()
    }

    func setZoom(_ factor: CGFloat) {
        guard let device else { return }
        try? device.lockForConfiguration()
        device.ramp(toVideoZoomFactor: min(max(1, factor), device.activeFormat.videoMaxZoomFactor), withRate: 6)
        device.unlockForConfiguration()
        zoom = factor
    }
}

extension UIImage {
    /// Centred square crop whose side is `fraction` of the shorter edge.
    func centerSquare(fraction: CGFloat) -> UIImage {
        guard let cg = cgImage else { return self }
        let side = CGFloat(min(cg.width, cg.height)) * min(1, max(0.1, fraction))
        let rect = CGRect(x: (CGFloat(cg.width) - side) / 2, y: (CGFloat(cg.height) - side) / 2, width: side, height: side).integral
        guard let cropped = cg.cropping(to: rect) else { return self }
        return UIImage(cgImage: cropped)
    }
}

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ view: PreviewView, context: Context) {}
}

/// Full-screen custom camera with a live diagnosis read-out.
struct LiveCameraView: View {
    var onCapture: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var camera = LiveCamera()
    @State private var capturing = false
    @State private var flash = false

    var body: some View {
        GeometryReader { geo in
            let square = min(geo.size.width * 0.8, 340)
            ZStack {
                Color.black.ignoresSafeArea()
                switch camera.status {
                case .running, .starting:
                    CameraPreview(session: camera.session).ignoresSafeArea()
                    viewfinder(square: square, size: geo.size)
                case .unavailable:
                    unavailable("camera.badge.ellipsis", "No camera here",
                                "The iOS Simulator doesn't have a camera. Run PlantGuard on your iPhone to scan live, or pick a photo instead.")
                case .denied:
                    unavailable("lock.fill", "Camera access is off",
                                "Allow camera access for PlantGuard in Settings to scan leaves live.", showsSettings: true)
                }
                if flash { Color.white.ignoresSafeArea().transition(.opacity) }
            }
            .task {
                // Map the on-screen square onto the portrait 3:4 video frame shown aspect-fill.
                let videoWidthOnScreen = max(geo.size.width, (geo.size.height + geo.safeAreaInsets.top + geo.safeAreaInsets.bottom) * 0.75)
                camera.cropFraction = square / videoWidthOnScreen
                await camera.start()
            }
        }
        .statusBarHidden()
        .onDisappear { camera.stop() }
    }

    private func viewfinder(square: CGFloat, size: CGSize) -> some View {
        let live = camera.live
        let color = live?.top.color ?? Theme.parchment
        return ZStack {
            // Dim everything outside the scan square.
            Rectangle().fill(.black.opacity(0.45)).ignoresSafeArea()
                .mask {
                    Rectangle().ignoresSafeArea()
                        .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).frame(width: square, height: square).blendMode(.destinationOut))
                        .compositingGroup()
                }
                .allowsHitTesting(false)
            ScanBrackets(color: camera.stability > 0.8 ? color : Theme.parchment, lineWidth: 4)
                .frame(width: square + 14, height: square + 14)
                .scaleEffect(camera.stability > 0.8 ? 1.0 : 1.03)
                .animation(.spring(response: 0.4, dampingFraction: 0.6), value: camera.stability > 0.8)

            livePill(live, color: color)
                .offset(y: -(square / 2 + 46))

            VStack {
                HStack {
                    circleButton("xmark") { dismiss() }
                    Spacer()
                    Text("Live").font(.system(size: 12, weight: .bold)).textCase(.uppercase).tracking(1.5)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .foregroundStyle(.white)
                        .background(Capsule().fill(Theme.danger.opacity(camera.status == .running ? 0.85 : 0.3)))
                    Spacer()
                    circleButton(camera.torchOn ? "flashlight.on.fill" : "flashlight.off.fill") { camera.toggleTorch() }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)

                Spacer()

                HStack(spacing: 10) {
                    ForEach([1.0, 2.0, 3.0], id: \.self) { z in
                        Button {
                            Haptics.tap()
                            camera.setZoom(z)
                        } label: {
                            Text(z == 1 ? "1×" : "\(Int(z))×").font(.system(size: 13, weight: .bold))
                                .frame(width: 40, height: 40)
                                .foregroundStyle(camera.zoom == z ? Theme.amber : .white)
                                .background(Circle().fill(.black.opacity(0.45)))
                        }
                    }
                }
                .padding(.bottom, 18)

                Button(action: capture) {
                    ZStack {
                        Circle().strokeBorder(.white, lineWidth: 4).frame(width: 82, height: 82)
                        Circle()
                            .trim(from: 0, to: camera.stability)
                            .stroke(color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .frame(width: 94, height: 94)
                        Circle().fill(capturing ? Theme.rust : .white).frame(width: 66, height: 66)
                            .scaleEffect(capturing ? 0.85 : 1)
                    }
                }
                .disabled(capturing)
                Text(hint(live)).font(.system(size: 13, weight: .medium)).foregroundStyle(.white.opacity(0.85))
                    .padding(.top, 10).padding(.bottom, 24)
                    .contentTransition(.opacity)
            }
        }
    }

    private func livePill(_ live: Classification?, color: Color) -> some View {
        HStack(spacing: 8) {
            if let live {
                Circle().fill(color).frame(width: 9, height: 9).shadow(color: color, radius: 5)
                Text(live.top.name).font(.system(size: 15, weight: .semibold))
                Text(live.confidence, format: .percent.precision(.fractionLength(0))).font(.mono(14))
                    .contentTransition(.numericText())
            } else {
                ProgressView().tint(.white).scaleEffect(0.8)
                Text("Looking for a leaf…").font(.system(size: 14, weight: .medium))
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(Capsule().fill(.ultraThinMaterial))
        .overlay(Capsule().strokeBorder(color.opacity(0.5), lineWidth: 1))
    }

    private func hint(_ live: Classification?) -> String {
        guard let live else { return "Fill the square with one leaf" }
        if live.isUncertain { return "Move closer and hold steady" }
        return camera.stability > 0.8 ? "Locked on — tap to analyze" : "Hold steady…"
    }

    private func circleButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            Image(systemName: symbol).font(.system(size: 16, weight: .semibold)).foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(Circle().fill(.black.opacity(0.45)))
        }
    }

    private func capture() {
        capturing = true
        Haptics.soft()
        withAnimation(.easeOut(duration: 0.12)) { flash = true }
        Task {
            try? await Task.sleep(for: .milliseconds(120))
            withAnimation(.easeIn(duration: 0.25)) { flash = false }
            if let image = await camera.capturePhoto() {
                camera.stop()
                onCapture(image)
                dismiss()
            }
            capturing = false
        }
    }

    private func unavailable(_ symbol: String, _ title: String, _ message: String, showsSettings: Bool = false) -> some View {
        VStack(spacing: 18) {
            EmptyStateView(symbol: symbol, title: title, message: message)
            if showsSettings, let url = URL(string: UIApplication.openSettingsURLString) {
                Button("Open Settings") { UIApplication.shared.open(url) }.buttonStyle(PrimaryButtonStyle()).padding(.horizontal, 50)
            }
            Button("Close") { dismiss() }.buttonStyle(SecondaryButtonStyle()).padding(.horizontal, 50)
        }
        .background(AppBackground())
    }
}
