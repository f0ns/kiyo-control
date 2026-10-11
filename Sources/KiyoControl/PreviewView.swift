@preconcurrency import AVFoundation
import KiyoKit
import SwiftUI

/// Runs an AVCaptureSession on the Kiyo so changes can be judged before saving.
@MainActor
final class PreviewController: ObservableObject {
    let session = AVCaptureSession()
    /// Resolutions and frame rates the camera offers, and the one the preview uses.
    @Published private(set) var modes: [VideoMode] = []
    @Published private(set) var mode: VideoMode?
    var formatLabel: String { mode?.label ?? "" }
    @Published private(set) var status = "Starting preview…"
    @Published var enabled = true { didSet { enabled ? start() : stop() } }

    private let queue = DispatchQueue(label: "preview.session")
    private var configured = false
    private var device: AVCaptureDevice?
    private static let modeKey = "previewMode"

    func start() {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async { MainActor.assumeIsolated { self.accessResolved(granted) } }
        }
    }

    /// Opens the camera afresh after it was plugged in again, picking up its current formats.
    func reconnect() {
        session.beginConfiguration()
        session.inputs.forEach(session.removeInput)
        session.commitConfiguration()
        configured = false
        device = nil
        modes = []
        mode = nil
        status = "Starting preview…"
        // AVFoundation lists the camera a moment after USB does.
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            MainActor.assumeIsolated { if self.enabled { self.start() } }
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

        self.device = device
        modes = VideoMode.options(device.formats.map { f in
            let d = CMVideoFormatDescriptionGetDimensions(f.formatDescription)
            return VideoMode.Format(width: Int(d.width), height: Int(d.height),
                                    frameRates: f.videoSupportedFrameRateRanges.map(\.maxFrameRate))
        })
        let saved = UserDefaults.standard.string(forKey: Self.modeKey).flatMap(VideoMode.init)
        if let preferred = VideoMode.preferred(modes, saved: saved) { apply(preferred) }
        configured = true
        // KIYO_MODE_CYCLE=1 switches through every mode while streaming and logs what the camera runs (see scripts/smoke.sh).
        if ProcessInfo.processInfo.environment["KIYO_MODE_CYCLE"] != nil { cycleModes(0) }
    }
}

extension PreviewController {
    /// Switches the preview to a resolution and frame rate and remembers it.
    func select(_ mode: VideoMode) {
        if apply(mode) { UserDefaults.standard.set(mode.stored, forKey: Self.modeKey) }
    }

    /// The Kiyo reports 30 fps as 30.00003, and AVFoundation throws (uncatchable from Swift) for any
    /// duration outside a supported range, so only ever use durations the device itself reports.
    @discardableResult
    private func apply(_ mode: VideoMode) -> Bool {
        guard let device else { return false }
        for format in device.formats {
            let d = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
            guard Int(d.width) == mode.width, Int(d.height) == mode.height,
                  let range = format.videoSupportedFrameRateRanges.first(where: { Int($0.maxFrameRate.rounded()) == mode.fps })
            else { continue }
            guard (try? device.lockForConfiguration()) != nil else { return false }
            device.activeFormat = format
            // Keep min <= max at every step: set the bound that moves away from the other first.
            if range.minFrameDuration > device.activeVideoMaxFrameDuration {
                device.activeVideoMaxFrameDuration = range.maxFrameDuration
                device.activeVideoMinFrameDuration = range.minFrameDuration
            } else {
                device.activeVideoMinFrameDuration = range.minFrameDuration
                device.activeVideoMaxFrameDuration = range.maxFrameDuration
            }
            device.unlockForConfiguration()
            self.mode = mode
            return true
        }
        return false
    }
}

extension PreviewController {
    private func cycleModes(_ index: Int) {
        guard let device, index < modes.count else { return NSLog("Mode cycle done") }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            MainActor.assumeIsolated {
                let ok = self.apply(self.modes[index])
                let d = CMVideoFormatDescriptionGetDimensions(device.activeFormat.formatDescription)
                NSLog("Mode \(self.modes[index].label) applied=\(ok) running=\(d.width)x\(d.height)@\(1 / device.activeVideoMinFrameDuration.seconds)")
                self.cycleModes(index + 1)
            }
        }
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
