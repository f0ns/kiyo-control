import Foundation

/// Connection, live values, profiles and backups for one camera. UI-independent so it can be unit tested.
public final class CameraController {
    public private(set) var connected = false
    public private(set) var values: [String: Int] = [:]
    public private(set) var ranges: [String: UVCRange] = [:]
    public private(set) var savedValues: [String: Int] = [:]
    public private(set) var razer = RazerSettings()
    public private(set) var savedRazer = RazerSettings()
    public private(set) var activeProfile: String
    public private(set) var profileNames: [String] = []
    public private(set) var backups: [ProfileStore.Backup] = []
    public var lastError: String?

    public let store: ProfileStore
    private let controls: [UVCControl]
    private let connect: () -> UVCCamera?
    private var camera: UVCCamera?

    public init(store: ProfileStore, controls: [UVCControl] = KiyoProUltra.all,
                connect: @escaping () -> UVCCamera? = { UVCCamera() }) {
        self.store = store
        self.controls = controls
        self.connect = connect
        activeProfile = store.activeProfileName.flatMap { $0.isEmpty ? nil : $0 } ?? "Default"
        reloadLists()
    }

    /// Unsaved changes, ignoring values the camera drives itself while in auto mode.
    public var isDirty: Bool {
        razer != savedRazer || comparableValues(values, controls: controls) != comparableValues(savedValues, controls: controls)
    }

    private var manualExposure: Bool { values[KiyoProUltra.autoExposure.id] == 1 }

    public func value(_ c: UVCControl) -> Int { values[c.id] ?? ranges[c.id]?.defaultValue ?? 0 }

    public func isAuto(_ c: UVCControl) -> Bool { KiyoKit.isAuto(c.id, values[c.id]) }

    // MARK: Connection

    /// Connects when the camera appears and notices when it goes away. Call periodically.
    public func poll() {
        guard let camera else { return connectIfPossible() }
        do {
            _ = try camera.get(controls[0])
        } catch {
            self.camera = nil
            connected = false
        }
    }

    /// Re-reads values from the camera.
    public func refresh() {
        if let camera { values = camera.snapshot(controls) }
    }

    /// Writes the current values again, e.g. after the Mac wakes and the camera lost them.
    public func reapply() { apply(values, razer: razer) }

    private func connectIfPossible() {
        guard let cam = connect() else { return }
        var r: [String: UVCRange] = [:]
        for c in controls { r[c.id] = try? cam.range(c) }
        guard !r.isEmpty else { return }

        camera = cam
        ranges = r
        connected = true
        let current = cam.snapshot(controls)
        // Always keep the camera's state from before we touch anything.
        _ = try? store.backup(current, razer: razer, reason: "on-connect")

        if let profile = store.profile(named: activeProfile) {
            load(profile)
        } else {
            // First run: adopt whatever the camera has now (e.g. settings made in Synapse).
            values = current
            save()
        }
        reloadLists()
    }

    // MARK: Live changes

    public func set(_ c: UVCControl, _ newValue: Int) {
        guard let camera else { return }
        var v = newValue
        if let r = ranges[c.id], case .range = c.kind { v = min(max(v, r.min), r.max) }
        do {
            try camera.set(c, v)
            values[c.id] = v
            // Toggling an auto mode changes what the camera reports for the values it gates.
            if case .range = c.kind {} else { refresh() }
            if c.id == KiyoProUltra.autoExposure.id, manualExposure { send(razer.exposureCommands) }
        } catch {
            report(error, "Could not set \(c.name)")
        }
    }

    /// Changes Razer settings and sends only the commands that changed.
    public func setRazer(_ change: (inout RazerSettings) -> Void) {
        var next = razer
        change(&next)
        let before = razer.commands(manualExposure: manualExposure)
        razer = next
        send(next.commands(manualExposure: manualExposure).filter { !before.contains($0) })
    }

    public func resetToDefault(_ list: [UVCControl]) {
        for c in list { if let d = ranges[c.id]?.defaultValue { set(c, d) } }
    }

    // MARK: Profiles

    public func save() {
        do {
            try store.save(Profile(name: activeProfile, values: values, razer: razer))
            savedValues = values
            savedRazer = razer
            reloadLists()
        } catch { report(error, "Could not save profile") }
    }

    public func revert() { apply(savedValues, razer: savedRazer) }

    public func switchProfile(_ name: String) {
        guard let p = store.profile(named: name) else { return }
        activeProfile = name
        store.activeProfileName = name
        load(p)
    }

    public func createProfile(_ name: String) {
        let name = name.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty, !profileNames.contains(name) else { return }
        activeProfile = name
        store.activeProfileName = name
        save()
    }

    public func deleteActiveProfile() {
        guard profileNames.count > 1 else { return }
        try? store.deleteProfile(named: activeProfile)
        reloadLists()
        if let next = profileNames.first(where: { $0 != activeProfile }) { switchProfile(next) }
    }

    // MARK: Backups

    public func resetAll() {
        backupCurrent("before-reset")
        var neutral = razer
        neutral.mirror = false
        neutral.metering = .average
        neutral.exposureCompensation = 0
        neutral.faceFocus = false
        neutral.stylizedLighting = false
        apply(ranges.mapValues(\.defaultValue), razer: neutral)
    }

    public func restore(_ backup: ProfileStore.Backup) {
        backupCurrent("before-restore")
        apply(backup.profile.values, razer: backup.profile.razer)
    }

    // MARK: Helpers

    /// Applies a profile; what the camera ends up with becomes the saved baseline, so controls
    /// missing from older profiles don't count as unsaved changes.
    private func load(_ profile: Profile) {
        apply(profile.values, razer: profile.razer)
        savedValues = values
        savedRazer = razer
    }

    private func apply(_ target: [String: Int], razer target2: RazerSettings) {
        guard let camera else { return }
        let failed = camera.apply(target, ranges: ranges, controls: controls)
        values = camera.snapshot(controls)
        razer = target2
        send(razer.commands(manualExposure: manualExposure))
        if !failed.isEmpty {
            lastError = "Could not apply: " + failed.keys.compactMap { id in controls.first { $0.id == id }?.name }.joined(separator: ", ")
        }
    }

    private func backupCurrent(_ reason: String) {
        guard let camera else { return }
        do { try store.backup(camera.snapshot(controls), razer: razer, reason: reason) } catch { report(error, "Backup failed") }
        reloadLists()
    }

    private func send(_ commands: [[UInt8]]) {
        guard let camera else { return }
        for command in commands {
            do { try camera.send(command) } catch { report(error, "Could not apply a Razer setting") }
        }
    }

    private func reloadLists() {
        profileNames = store.profileNames()
        if !profileNames.contains(activeProfile) { profileNames.append(activeProfile) }
        backups = store.backups()
    }

    private func report(_ error: Error, _ context: String) {
        lastError = "\(context): \(error)"
        if (error as? UVCError)?.isDisconnected == true {
            camera = nil
            connected = false
        }
    }
}
