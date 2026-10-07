import Foundation
import Testing
@testable import KiyoKit

@Suite struct SaveToCameraTests {
    let fake = FakeTransport()

    @Test func sendsTheSameSequenceAsSynapse() throws {
        try UVCCamera(transport: fake).saveToCamera()
        #expect(fake.writes == [[0xC0, 0x09, 0x0A, 0, 0, 0, 0, 0], [0xC0, 0x03, 0xA8, 0, 0, 0, 0, 0]])
        #expect(fake.setLog.allSatisfy { $0 == .init(unit: 6, selector: 1) })
    }

    @Test func controllerBacksUpBeforeSaving() {
        fake.stub(K.zoom, cur: 150, min: 100, max: 400, def: 110)
        let store = ProfileStore(root: FileManager.default.temporaryDirectory.appending(path: "kiyo-sv-\(UUID().uuidString)"))
        let fake = fake
        let c = CameraController(store: store, controls: [K.zoom]) { UVCCamera(transport: fake) }
        c.poll()
        c.saveToCamera()
        #expect(store.backups().contains { $0.profile.name == "before-save-to-camera" })
        #expect(fake.writes.last == [0xC0, 0x03, 0xA8, 0, 0, 0, 0, 0])
    }

    @Test func noSaveWithoutCamera() {
        let store = ProfileStore(root: FileManager.default.temporaryDirectory.appending(path: "kiyo-sv-\(UUID().uuidString)"))
        let c = CameraController(store: store, controls: [K.zoom]) { nil }
        c.poll()
        c.saveToCamera()
        #expect(fake.writes.isEmpty)
    }
}

@Suite struct SaveAlsoWritesCameraTests {
    let fake = FakeTransport()
    let store = ProfileStore(root: FileManager.default.temporaryDirectory.appending(path: "kiyo-sv2-\(UUID().uuidString)"))
    let saveCommand: [UInt8] = [0xC0, 0x03, 0xA8, 0, 0, 0, 0, 0]

    func controller() -> CameraController {
        fake.stub(K.zoom, cur: 150, min: 100, max: 400, def: 110)
        let fake = fake
        let c = CameraController(store: store, controls: [K.zoom]) { UVCCamera(transport: fake) }
        c.poll()
        return c
    }

    @Test func saveWritesChangedRazerSettingsToTheCamera() {
        let c = controller()
        c.setRazer { $0.mirror = true }
        c.save()
        #expect(fake.writes.last == saveCommand)
        #expect(store.profile(named: "Default")?.razer.mirror == true)
    }

    @Test func saveWithOnlyStandardChangesDoesNotWriteTheCamera() {
        let c = controller()
        c.set(K.zoom, 300)
        c.save()
        #expect(!fake.writes.contains(saveCommand))
    }

    @Test func firstConnectNeverWritesTheCamera() {
        _ = controller()
        #expect(!fake.writes.contains(saveCommand))
    }
}
