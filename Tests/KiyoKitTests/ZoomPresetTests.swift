import Foundation
import Testing
@testable import KiyoKit

@Suite struct ZoomPresetTests {
    let fake = FakeTransport()
    let store = ProfileStore(root: FileManager.default.temporaryDirectory.appending(path: "kiyo-zp-\(UUID().uuidString)"))

    init() {
        fake.stub(K.zoom, cur: 150, min: 100, max: 400, def: 110)
        fake.current[fake.key(K.pan)] = FakeTransport.bytes(0, size: 8)
        fake.minimum[fake.key(K.pan)] = FakeTransport.bytes(-36000, size: 4) + FakeTransport.bytes(-36000, size: 4)
        fake.maximum[fake.key(K.pan)] = FakeTransport.bytes(36000, size: 4) + FakeTransport.bytes(36000, size: 4)
    }

    func controller() -> CameraController {
        let fake = fake
        let c = CameraController(store: store, controls: [K.zoom, K.pan, K.tilt]) { UVCCamera(transport: fake) }
        c.poll()
        return c
    }

    @Test func storesCurrentViewInASlot() {
        let c = controller()
        c.set(K.zoom, 250)
        c.set(K.pan, 3600)
        c.storeZoomPreset(2)
        #expect(c.zoomPresets[2] == ZoomPreset(zoom: 250, pan: 3600, tilt: 0))
        #expect(c.isDirty)
    }

    @Test func applyingAPresetMovesTheCamera() throws {
        let c = controller()
        c.set(K.zoom, 300)
        c.set(K.tilt, -7200)
        c.storeZoomPreset(0)
        c.set(K.zoom, 100)
        c.set(K.tilt, 0)
        c.applyZoomPreset(0)
        let cam = UVCCamera(transport: fake)
        #expect(try cam.get(K.zoom) == 300)
        #expect(try cam.get(K.tilt) == -7200)
    }

    @Test func emptyOrInvalidSlotsDoNothing() {
        let c = controller()
        let writes = fake.setLog.count
        c.applyZoomPreset(4)
        c.applyZoomPreset(9)
        c.storeZoomPreset(-1)
        #expect(fake.setLog.count == writes)
        #expect(c.zoomPresets.count == 5)
    }

    @Test func presetsAreSavedWithTheProfile() {
        let c = controller()
        c.storeZoomPreset(1)
        c.save()
        #expect(store.profile(named: "Default")?.zoomPresets[1] == ZoomPreset(zoom: 150, pan: 0, tilt: 0))
        #expect(!c.isDirty)
    }

    @Test func oldProfilesGetFiveEmptySlots() throws {
        let json = #"{"name":"Old","values":{},"savedAt":"2026-10-07T11:28:08Z"}"#
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        #expect(try dec.decode(Profile.self, from: Data(json.utf8)).zoomPresets == Array(repeating: nil, count: 5))
    }
}
