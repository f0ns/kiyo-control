import Foundation
import Testing
@testable import KiyoKit

typealias K = KiyoProUltra

@Suite struct UVCCameraTests {
    let fake = FakeTransport()
    var camera: UVCCamera { UVCCamera(transport: fake) }

    @Test func readsSignedValues() throws {
        fake.current[fake.key(K.brightness)] = [0xFF, 0xFF]
        #expect(try camera.get(K.brightness) == -1)
    }

    @Test func writesLittleEndian() throws {
        try camera.set(K.whiteBalance, 5000)
        #expect(fake.current[fake.key(K.whiteBalance)] == [0x88, 0x13])
    }

    @Test func settingPanKeepsTilt() throws {
        fake.current[fake.key(K.pan)] = FakeTransport.bytes(0, size: 4) + FakeTransport.bytes(-7200, size: 4)
        try camera.set(K.pan, 3600)
        #expect(try camera.get(K.pan) == 3600)
        #expect(try camera.get(K.tilt) == -7200)
    }

    @Test func rangeReadsMinMaxDefault() throws {
        fake.stub(K.zoom, cur: 150, min: 100, max: 400, def: 110)
        #expect(try camera.range(K.zoom) == UVCRange(min: 100, max: 400, step: 1, defaultValue: 110))
    }

    @Test func toggleRangeIsZeroToOne() throws {
        fake.stub(K.autoFocus, cur: 1, def: 1)
        #expect(try camera.range(K.autoFocus) == UVCRange(min: 0, max: 1, step: 1, defaultValue: 1))
    }

    @Test func snapshotSkipsFailingControls() {
        fake.stub(K.zoom, cur: 150)
        fake.stub(K.focus, cur: 10)
        fake.failing = [fake.key(K.focus)]
        let snap = camera.snapshot([K.zoom, K.focus])
        #expect(snap == ["zoom": 150])
    }

    @Test func applyWritesAutoToggleBeforeGatedValue() {
        let ranges = ["focus": UVCRange(min: 1, max: 450, step: 1, defaultValue: 1)]
        camera.apply(["focus": 300, "autoFocus": 0], ranges: ranges)
        #expect(fake.setLog == [fake.key(K.autoFocus), fake.key(K.focus)])
    }

    @Test func applySkipsGatedValueWhileAutoIsOn() {
        camera.apply(["focus": 300, "autoFocus": 1], ranges: [:])
        #expect(fake.setLog == [fake.key(K.autoFocus)])
    }

    @Test func applyClampsToRange() throws {
        camera.apply(["zoom": 9999], ranges: ["zoom": UVCRange(min: 100, max: 400, step: 1, defaultValue: 100)])
        #expect(try camera.get(K.zoom) == 400)
    }

    @Test func applyContinuesPastFailures() {
        fake.failing = [fake.key(K.brightness)]
        let failed = camera.apply(["brightness": 1, "contrast": 2], ranges: [:])
        #expect(Array(failed.keys) == ["brightness"])
        #expect(fake.setLog == [fake.key(K.contrast)])
    }

    @Test func comparableValuesIgnoreAutoDrivenValues() {
        let a = ["autoExposure": 8, "exposureTime": 100, "zoom": 150]
        let b = ["autoExposure": 8, "exposureTime": 222, "zoom": 150]
        let controls = [K.autoExposure, K.exposureTime, K.zoom]
        #expect(comparableValues(a, controls: controls) == comparableValues(b, controls: controls))
        #expect(comparableValues(a.merging(["autoExposure": 1]) { $1 }, controls: controls)
            != comparableValues(b.merging(["autoExposure": 1]) { $1 }, controls: controls))
    }

    @Test func razerIsoAndShutterReplaceUVCGainAndExposureTime() {
        // The UVC versions conflict with Razer's ISO/shutter commands, so profiles don't carry them.
        #expect(!K.all.contains(K.gain))
        #expect(!K.all.contains(K.exposureTime))
    }

    @Test func oldProfileValuesForRemovedControlsAreNotWritten() {
        fake.stub(K.gain, cur: 0)
        camera.apply(["gain": 50, "autoExposure": 1], ranges: [:])
        #expect(!fake.setLog.contains(fake.key(K.gain)))
    }
}

@Suite struct KiyoDeviceTests {
    @Test func v2ProUsesItsOwnProcessingUnitId() throws {
        let fake = FakeTransport()
        let cam = UVCCamera(transport: fake, device: .v2Pro)
        try cam.set(K.brightness, 10)
        try cam.set(K.zoom, 150)
        #expect(fake.setLog.map(\.unit) == [2, 1])
    }

    @Test func proUltraKeepsUnit3() throws {
        let fake = FakeTransport()
        try UVCCamera(transport: fake).set(K.brightness, 10)
        #expect(fake.setLog.map(\.unit) == [3])
    }

    @Test func v2ProNeverReceivesRazerCommands() throws {
        let fake = FakeTransport()
        fake.stub(K.zoom, cur: 100, min: 100, max: 400, def: 100)
        let store = ProfileStore(root: FileManager.default.temporaryDirectory.appending(path: "kiyo-v2-\(UUID().uuidString)"))
        let c = CameraController(store: store, controls: [K.zoom]) { UVCCamera(transport: fake, device: .v2Pro) }
        c.poll()
        c.setRazer { $0.mirror = true; $0.iso = 400 }
        c.saveToCamera()
        #expect(!c.supportsRazer)
        #expect(!fake.setLog.contains { $0.unit == RazerCommand.unit })
    }
}

@Suite struct V2ProExposureTests {
    @Test func v2ProManualExposureUsesStandardControls() throws {
        let fake = FakeTransport()
        fake.stub(K.zoom, cur: 100, min: 100, max: 400, def: 100)
        fake.stub(K.autoExposure, cur: 1, min: 1, max: 8, def: 8)
        fake.stub(K.exposureTime, cur: 100, min: 10, max: 2000, def: 100)
        fake.stub(K.gain, cur: 5, min: 0, max: 100, def: 0)
        // The V2 Pro's Processing Unit is id 2, not 3.
        let (from, to) = (fake.key(K.gain), FakeTransport.Key(unit: 2, selector: K.gain.selector))
        fake.current[to] = fake.current[from]; fake.minimum[to] = fake.minimum[from]
        fake.maximum[to] = fake.maximum[from]; fake.defaults[to] = fake.defaults[from]
        let store = ProfileStore(root: FileManager.default.temporaryDirectory.appending(path: "kiyo-v2e-\(UUID().uuidString)"))
        let c = CameraController(store: store, controls: [K.zoom, K.autoExposure]) { UVCCamera(transport: fake, device: .v2Pro) }
        c.poll()
        #expect(c.ranges["exposureTime"]?.max == 2000)
        #expect(c.ranges["gain"]?.max == 100)
        c.set(K.exposureTime, 5000)
        #expect(c.value(K.exposureTime) == 2000)
    }

    @Test func proUltraDoesNotUseStandardExposureControls() {
        let fake = FakeTransport()
        fake.stub(K.zoom, cur: 100, min: 100, max: 400, def: 100)
        let store = ProfileStore(root: FileManager.default.temporaryDirectory.appending(path: "kiyo-ue-\(UUID().uuidString)"))
        let c = CameraController(store: store, controls: [K.zoom]) { UVCCamera(transport: fake) }
        c.poll()
        #expect(c.ranges["exposureTime"] == nil)
    }
}
