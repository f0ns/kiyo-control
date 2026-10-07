import KiyoKit
import SwiftUI

/// SwiftUI wrapper around CameraController: forwards calls and publishes changes.
@MainActor
final class CameraModel: ObservableObject {
    let controller = CameraController(store: ProfileStore())
    private var pollTimer: Timer?

    init() {
        poll()
        ZoomPresetHotKeys.register { [weak self] slot in
            MainActor.assumeIsolated { self?.applyZoomPreset(slot) }
        }
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

    func poll() { perform { $0.poll() } }
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
    func setRazer(_ change: (inout RazerSettings) -> Void) { perform { $0.setRazer(change) } }
}

extension CameraModel {
    var zoomPresets: [ZoomPreset?] { controller.zoomPresets }
    func storeZoomPreset(_ slot: Int) { perform { $0.storeZoomPreset(slot) } }
    func applyZoomPreset(_ slot: Int) { perform { $0.applyZoomPreset(slot) } }
}

extension CameraModel {
    func saveToCamera() { perform { $0.saveToCamera() } }
}
