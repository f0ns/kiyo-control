import Foundation
import Testing
@testable import KiyoKit

@Suite struct CameraControllerTests {
    let fake = FakeTransport()
    let store = ProfileStore(root: FileManager.default.temporaryDirectory.appending(path: "kiyo-cc-\(UUID().uuidString)"))

    init() {
        fake.stub(K.zoom, cur: 150, min: 100, max: 400, def: 110)
        fake.stub(K.brightness, cur: 90, min: 0, max: 255, def: 128)
        fake.stub(K.autoExposure, cur: 8, def: 8)
        fake.stub(K.exposureTime, cur: 156, min: 3, max: 2047, def: 156)
    }

    func controller(_ controls: [UVCControl] = [K.zoom, K.brightness, K.autoExposure, K.exposureTime]) -> CameraController {
        let fake = fake
        return CameraController(store: store, controls: controls) { UVCCamera(transport: fake) }
    }

    @Test func firstConnectAdoptsCameraValuesWithoutWriting() {
        let c = controller()
        c.poll()
        #expect(c.connected)
        #expect(c.values["brightness"] == 90)
        #expect(fake.setLog.isEmpty)
        #expect(store.profile(named: "Default")?.values["zoom"] == 150)
        #expect(!c.isDirty)
    }

    @Test func connectBacksUpCameraFirst() {
        controller().poll()
        #expect(store.backups().first?.profile.values["brightness"] == 90)
        #expect(store.backups().first?.profile.name == "on-connect")
    }

    @Test func connectAppliesActiveProfile() throws {
        try store.save(Profile(name: "Default", values: ["zoom": 300, "brightness": 90]))
        let c = controller()
        c.poll()
        #expect(c.values["zoom"] == 300)
        #expect(!c.isDirty)
    }

    @Test func liveChangeIsDirtyUntilSaved() {
        let c = controller()
        c.poll()
        c.set(K.brightness, 120)
        #expect(c.values["brightness"] == 120)
        #expect(c.isDirty)
        c.save()
        #expect(!c.isDirty)
        #expect(store.profile(named: "Default")?.values["brightness"] == 120)
    }

    @Test func revertRestoresSavedValuesOnCamera() throws {
        let c = controller()
        c.poll()
        c.set(K.brightness, 200)
        c.revert()
        #expect(try UVCCamera(transport: fake).get(K.brightness) == 90)
        #expect(!c.isDirty)
    }

    @Test func setClampsToRange() {
        let c = controller()
        c.poll()
        c.set(K.zoom, 10)
        #expect(c.values["zoom"] == 100)
    }

    @Test func autoExposureDriftIsNotDirty() {
        let c = controller()
        c.poll()
        fake.current[fake.key(K.exposureTime)] = FakeTransport.bytes(400, size: 4)
        c.refresh()
        #expect(!c.isDirty)
    }

    @Test func resetAllBacksUpThenAppliesDefaults() throws {
        let c = controller()
        c.poll()
        c.resetAll()
        #expect(c.values["brightness"] == 128)
        #expect(store.backups().contains { $0.profile.name == "before-reset" && $0.profile.values["brightness"] == 90 })
    }

    @Test func restoreBacksUpThenApplies() throws {
        let c = controller()
        c.poll()
        let url = try store.backup(["brightness": 10], reason: "old")
        c.restore(try #require(store.backups().first { $0.url.lastPathComponent == url.lastPathComponent }))
        #expect(c.values["brightness"] == 10)
        #expect(store.backups().contains { $0.profile.name == "before-restore" })
    }

    @Test func switchingProfileAppliesIt() throws {
        try store.save(Profile(name: "Streaming", values: ["zoom": 250]))
        let c = controller()
        c.poll()
        c.switchProfile("Streaming")
        #expect(c.activeProfile == "Streaming")
        #expect(c.values["zoom"] == 250)
        #expect(store.activeProfileName == "Streaming")
    }

    @Test func createProfileSavesCurrentValues() {
        let c = controller()
        c.poll()
        c.set(K.zoom, 200)
        c.createProfile("Calls")
        #expect(c.activeProfile == "Calls")
        #expect(store.profile(named: "Calls")?.values["zoom"] == 200)
        #expect(c.profileNames.contains("Calls"))
    }

    @Test func detectsUnplugAndReconnects() {
        let c = controller()
        c.poll()
        fake.failing = Set(fake.current.keys)
        c.poll()
        #expect(!c.connected)
        fake.failing = []
        c.poll()
        #expect(c.connected)
    }

    @Test func notConnectedWhenCameraAbsent() {
        let c = CameraController(store: store, controls: [K.zoom]) { nil }
        c.poll()
        #expect(!c.connected)
    }

    @Test func reapplyRestoresValuesTheCameraLost() throws {
        let c = controller()
        c.poll()
        c.set(K.zoom, 250)
        // Camera resets itself, e.g. across sleep.
        fake.current[fake.key(K.zoom)] = FakeTransport.bytes(110, size: 2)
        c.reapply()
        #expect(try UVCCamera(transport: fake).get(K.zoom) == 250)
        #expect(c.values["zoom"] == 250)
    }
}
