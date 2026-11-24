import KiyoKit
import SwiftUI

/// SwiftUI wrapper around CameraController: forwards calls and publishes changes.
@MainActor
final class CameraModel: ObservableObject {
    let controller = CameraController(store: ProfileStore()) {
        UVCCamera(preferring: CameraModel.preferredLocation)
    }
    /// Every USB camera plugged in, supported or not, for the camera list.
    private(set) var cameras: [USBCamera] = []
    /// The connected camera's USB connection; on USB 2 it offers no 4K.
    var link: USBLink? { cameras.first { $0.locationID == controller.cameraLocation }?.link }
    private var pollTimer: Timer?
    nonisolated private static let preferredKey = "preferredCamera"

    /// USB port of the camera the user picked last; nil means the first supported one.
    nonisolated static var preferredLocation: UInt32? {
        (UserDefaults.standard.object(forKey: preferredKey) as? NSNumber)?.uint32Value
    }

    init() {
        poll()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.poll() }
        }
        // The camera can lose its settings across sleep, so write them again after wake.
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                MainActor.assumeIsolated { self?.perform { $0.reapply() } }
            }
        }
    }

    /// Runs a controller action and tells SwiftUI to redraw.
    @discardableResult
    func perform<T>(_ action: (CameraController) -> T) -> T {
        objectWillChange.send()
        return action(controller)
    }

    /// Redraws only when the connection or the list of cameras changes, not on every 2-second check.
    func poll() {
        let wasConnected = controller.connected
        controller.poll()
        let found = CameraDiscovery.scan()
        if controller.connected != wasConnected || found != cameras {
            objectWillChange.send()
            cameras = found
        }
    }

    /// Switches to another supported camera and remembers the choice.
    func select(_ camera: USBCamera) {
        guard camera.device != nil, camera.locationID != controller.cameraLocation else { return }
        UserDefaults.standard.set(camera.locationID, forKey: Self.preferredKey)
        perform { $0.reconnect() }
        poll()
    }

    /// Supported cameras plugged in right now.
    var supportedCameras: [USBCamera] { cameras.filter { $0.device != nil } }
}

extension CameraModel {
    var connected: Bool { controller.connected }
    func value(_ c: UVCControl) -> Int { controller.value(c) }
    func range(_ c: UVCControl) -> UVCRange? { controller.ranges[c.id] }
    func isAuto(_ c: UVCControl) -> Bool { controller.isAuto(c) }
    func set(_ c: UVCControl, _ v: Int) { perform { $0.set(c, v) } }
    func resetToDefault(_ list: [UVCControl]) { perform { $0.resetToDefault(list) } }
}

extension CameraModel {
    var isDirty: Bool { controller.isDirty }
    func save() { perform { $0.save() } }
    func revert() { perform { $0.revert() } }
    func switchProfile(_ name: String) { perform { $0.switchProfile(name) } }
    func createProfile(_ name: String) { perform { $0.createProfile(name) } }
    func deleteActiveProfile() { perform { $0.deleteActiveProfile() } }
    func resetAll() { perform { $0.resetAll() } }
    func restore(_ backup: ProfileStore.Backup) { perform { $0.restore(backup) } }
    func revealBackups() { NSWorkspace.shared.open(controller.store.root.appending(path: "backups")) }
}

extension CameraModel {
    var razer: RazerSettings { controller.razer }
    var supportsRazer: Bool { controller.supportsRazer }
    var deviceName: String { controller.device.name }
    var supports4K: Bool { controller.device.supports4K }
    func setRazer(_ change: (inout RazerSettings) -> Void) { perform { $0.setRazer(change) } }
}

extension CameraModel {
    var zoomPresets: [ZoomPreset?] { controller.zoomPresets }
    func storeZoomPreset(_ slot: Int) { perform { $0.storeZoomPreset(slot) } }
    func applyZoomPreset(_ slot: Int) { perform { $0.applyZoomPreset(slot) } }
}
