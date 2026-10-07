import Foundation
import Testing
@testable import KiyoKit

@Suite struct RazerSettingsTests {
    let fake = FakeTransport()
    let store = ProfileStore(root: FileManager.default.temporaryDirectory.appending(path: "kiyo-rz-\(UUID().uuidString)"))

    init() {
        fake.stub(K.zoom, cur: 150, min: 100, max: 400, def: 110)
        fake.stub(K.autoExposure, cur: 8, def: 8)
    }

    func controller() -> CameraController {
        let fake = fake
        return CameraController(store: store, controls: [K.zoom, K.autoExposure]) { UVCCamera(transport: fake) }
    }

    var razerWrites: [[UInt8]] { zip(fake.setLog, fake.writes).filter { $0.0.unit == 6 }.map(\.1) }

    @Test func unknownSettingsProduceNoCommands() {
        #expect(RazerSettings().commands(manualExposure: true).isEmpty)
    }

    @Test func focusCommandCombinesModeAndLighting() {
        let s = RazerSettings(faceFocus: true, stylizedLighting: nil)
        #expect(s.commands(manualExposure: false) == [RazerCommand.focus(face: true, stylized: false)])
    }

    @Test func isoAndShutterOnlyInManualExposure() {
        let s = RazerSettings(iso: 400, shutterMicroseconds: 16_666)
        #expect(s.commands(manualExposure: false).isEmpty)
        #expect(s.commands(manualExposure: true) == [RazerCommand.iso(400), RazerCommand.shutter(microseconds: 16_666)])
    }

    @Test func profilesWithoutRazerSettingsStillLoad() throws {
        let json = #"{"name":"Old","values":{"zoom":150},"savedAt":"2026-10-07T11:28:08Z"}"#
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        let p = try dec.decode(Profile.self, from: Data(json.utf8))
        #expect(p.razer == RazerSettings())
    }

    @Test func firstConnectSendsNoRazerCommands() {
        controller().poll()
        #expect(razerWrites.isEmpty)
    }

    @Test func changingASettingSendsOnlyThatCommand() {
        let c = controller()
        c.poll()
        c.setRazer { $0.mirror = true }
        #expect(razerWrites == [RazerCommand.mirror(true)])
        #expect(c.isDirty)
    }

    @Test func savedRazerSettingsAreAppliedOnConnect() throws {
        try store.save(Profile(name: "Default", values: ["zoom": 150], razer: RazerSettings(mirror: true, metering: .face)))
        controller().poll()
        #expect(razerWrites == [RazerCommand.mirror(true), RazerCommand.metering(.face)])
    }

    @Test func saveAndRevertCoverRazerSettings() {
        let c = controller()
        c.poll()
        c.setRazer { $0.mirror = true }
        c.save()
        #expect(store.profile(named: "Default")?.razer.mirror == true)
        c.setRazer { $0.mirror = false }
        c.revert()
        #expect(razerWrites.last == RazerCommand.mirror(true))
        #expect(!c.isDirty)
    }

    @Test func switchingToManualExposureSendsIsoAndShutter() {
        let c = controller()
        c.poll()
        c.setRazer { $0.iso = 800 }
        #expect(razerWrites.isEmpty)  // auto exposure is on
        c.set(K.autoExposure, 1)
        #expect(razerWrites == [RazerCommand.iso(800)])
    }

    @Test func backupsIncludeKnownRazerSettings() {
        let c = controller()
        c.poll()
        c.setRazer { $0.mirror = true }
        c.resetAll()
        #expect(store.backups().first { $0.profile.name == "before-reset" }?.profile.razer.mirror == true)
    }
}
