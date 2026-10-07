@preconcurrency import AVFoundation
import SwiftUI

/// Runs an AVCaptureSession on the Kiyo so changes can be judged before saving.
@MainActor
final class PreviewController: ObservableObject {
    let session = AVCaptureSession()
    @Published private(set) var formatLabel = ""
    @Published private(set) var status = "Starting preview…"
    @Published var enabled = true { didSet { enabled ? start() : stop() } }

    private let queue = DispatchQueue(label: "preview.session")
    private var configured = false

    func start() {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async { MainActor.assumeIsolated { self.accessResolved(granted) } }
        }
    }

    func stop() {
        let session = session
        queue.async { session.stopRunning() }
    }

    private func accessResolved(_ granted: Bool) {
        guard granted else {
            status = "Camera access denied. Allow it in System Settings › Privacy & Security › Camera."
            return
        }
        if !configured { configure() }
        guard configured, enabled else { return }
        status = ""
        let session = session
        queue.async { session.startRunning() }
    }

    private func configure() {
        let devices = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.external], mediaType: .video, position: .unspecified).devices
        guard let device = devices.first(where: { $0.localizedName.localizedCaseInsensitiveContains("Kiyo") }) else {
            status = "Kiyo Pro Ultra not found"
            return
        }
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        guard let input = try? AVCaptureDeviceInput(device: device), session.canAddInput(input) else {
            status = "Could not open the camera"
            return
        }
        session.addInput(input)

        // Largest format that does 30 fps, like Synapse's 4K 30FPS preview.
        // The Kiyo reports 30 fps as 30.00003, and AVFoundation throws (uncatchable from Swift) for any
        // duration outside a supported range, so only ever use a duration the device itself reports.
        let best = device.formats
            .compactMap { format in
                format.videoSupportedFrameRateRanges
                    .first { abs($0.maxFrameRate - 30) < 0.5 }
                    .map { (format, $0.minFrameDuration) }
            }
            .max { CMVideoFormatDescriptionGetDimensions($0.0.formatDescription).width
                < CMVideoFormatDescriptionGetDimensions($1.0.formatDescription).width }
        if let (format, duration) = best, (try? device.lockForConfiguration()) != nil {
            device.activeFormat = format
            device.activeVideoMinFrameDuration = duration
            device.unlockForConfiguration()
        }
        let d = CMVideoFormatDescriptionGetDimensions(device.activeFormat.formatDescription)
        let fps = Int((1 / device.activeVideoMinFrameDuration.seconds).rounded())
        formatLabel = (d.height >= 2160 ? "4K" : "\(d.height)p") + " \(fps)FPS"
        configured = true
    }
}

struct PreviewView: NSViewRepresentable {
    let session: AVCaptureSession

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspect
        layer.backgroundColor = NSColor.black.cgColor
        view.layer = layer
        view.wantsLayer = true
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}
