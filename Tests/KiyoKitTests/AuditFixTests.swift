import Foundation
import Testing
@testable import KiyoKit

/// Regression tests for issues found in the pre-release audit.
@Suite struct AuditFixTests {
    let fake = FakeTransport()
    let dir = FileManager.default.temporaryDirectory.appending(path: "kiyo-audit-\(UUID().uuidString)")

    func controller(_ store: ProfileStore) -> CameraController {
        fake.stub(K.zoom, cur: 150, min: 100, max: 400, def: 110)
        let fake = fake
        let c = CameraController(store: store, controls: [K.zoom]) { UVCCamera(transport: fake) }
        c.poll()
        return c
    }

    @Test func newProfileNeverOverwritesAnExistingFile() throws {
        let store = ProfileStore(root: dir)
        let c = controller(store)  // creates "Default" with zoom 150
        c.set(K.zoom, 300)
        c.createProfile("default")  // same file on a case-insensitive disk
        c.createProfile("Default")
        #expect(store.profile(named: "Default")?.values["zoom"] == 150)
        #expect(c.activeProfile == "Default")
    }

    @Test func profilesThatMapToTheSameFileAreRefused() throws {
        let store = ProfileStore(root: dir)
        let c = controller(store)
        c.createProfile("a/b")
        c.set(K.zoom, 300)
        c.createProfile("a-b")
        #expect(store.profile(named: "a/b")?.values["zoom"] == 150)
        #expect(c.activeProfile == "a/b")
    }

    @Test func connectBackupsDoNotPushOutOtherBackups() throws {
        let store = ProfileStore(root: dir, maxBackups: 4)
        try store.backup(["zoom": 1], reason: "before-reset")
        for i in 0..<10 { try store.backup(["zoom": 100 + i], reason: "on-connect") }
        #expect(store.backups().contains { $0.profile.name == "before-reset" })
    }

    @Test func identicalConnectBackupsAreNotRepeated() throws {
        let store = ProfileStore(root: dir)
        for _ in 0..<5 { try store.backup(["zoom": 150], reason: "on-connect") }
        #expect(store.backups().count == 1)
    }

    @Test func backupsInTheSameSecondDoNotOverwriteEachOther() throws {
        let store = ProfileStore(root: dir)
        try store.backup(["zoom": 1], reason: "before-reset")
        try store.backup(["zoom": 2], reason: "before-reset")
        #expect(store.backups().count == 2)
    }

    @Test func faceMeteringClampsCompensationToItsRange() {
        let s = RazerSettings(metering: .face, exposureCompensation: -30)
        #expect(s.commands(manualExposure: false).contains(RazerCommand.exposureCompensation(-10)))
    }
}
