import Foundation
import Testing
@testable import KiyoKit

@Suite struct CameraDiscoveryTests {
    static func camera(_ product: UInt16, vendor: UInt16 = 0x1532, at location: UInt32, name: String = "Razer Kiyo") -> USBCamera {
        USBCamera(name: name, vendorID: vendor, productID: product, locationID: location,
                  link: USBLink(bitsPerSecond: 480_000_000))
    }

    @Test func classifiesCameras() {
        #expect(Self.camera(0x0E0C, at: 1).status == .supported(.v2X))
        #expect(Self.camera(0x0E08, at: 1).status == .supported(.proUltra))
        #expect(Self.camera(0x0E03, at: 1).status == .unsupportedRazer)
        #expect(Self.camera(0x085C, vendor: 0x046D, at: 1).status == .other)
        #expect(Self.camera(0x0E03, at: 1).device == nil)
    }

    @Test func formatsTheUSBId() {
        #expect(Self.camera(0x0E0C, at: 1).usbID == "1532:0E0C")
    }

    @Test func choosesThePreferredSupportedCamera() {
        let cams = [Self.camera(0x0E03, at: 1), Self.camera(0x0E08, at: 2), Self.camera(0x0E0C, at: 3)]
        #expect(CameraDiscovery.choose(cams, preferring: 3)?.locationID == 3)
        // Unplugged or unsupported preference: the first supported camera.
        #expect(CameraDiscovery.choose(cams, preferring: 9)?.locationID == 2)
        #expect(CameraDiscovery.choose(cams, preferring: 1)?.locationID == 2)
        #expect(CameraDiscovery.choose(cams, preferring: nil)?.locationID == 2)
    }

    @Test func choosesNothingWithoutASupportedCamera() {
        #expect(CameraDiscovery.choose([Self.camera(0x0E03, at: 1)], preferring: 1) == nil)
        #expect(CameraDiscovery.choose([], preferring: nil) == nil)
    }

    @Test func supportRequestNamesTheCamera() throws {
        let url = CameraDiscovery.supportRequestURL(for: Self.camera(0x0E03, at: 1, name: "Razer Kiyo"))
        let items = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
        #expect(url.host == "github.com")
        #expect(items.first { $0.name == "title" }?.value == "Support Razer Kiyo (1532:0E03)")
        #expect(items.first { $0.name == "body" }?.value?.contains("tools/uvc-dump 1532 0E03") == true)
    }

}

@Suite struct ReconnectTests {
    @Test func reconnectSwitchesToTheNewlyChosenCamera() {
        let fake = FakeTransport()
        fake.stub(K.zoom, cur: 100, min: 100, max: 400, def: 100)
        var next = (KiyoDevice.proUltra, UInt32(1))
        var connects = 0
        let store = ProfileStore(root: FileManager.default.temporaryDirectory.appending(path: "kiyo-rc-\(UUID().uuidString)"))
        let c = CameraController(store: store, controls: [K.zoom]) {
            connects += 1
            return UVCCamera(transport: fake, device: next.0, locationID: next.1)
        }
        c.poll()
        #expect(c.connected && c.cameraLocation == 1 && c.device == .proUltra)

        next = (.v2X, 2)
        c.reconnect()
        #expect(connects == 2)
        #expect(c.connected && c.cameraLocation == 2 && c.device == .v2X)
        #expect(!c.supportsRazer)
    }

    @Test func reconnectWithoutACameraStaysDisconnected() {
        let store = ProfileStore(root: FileManager.default.temporaryDirectory.appending(path: "kiyo-rc0-\(UUID().uuidString)"))
        let c = CameraController(store: store, controls: [K.zoom]) { nil }
        c.reconnect()
        #expect(!c.connected && c.cameraLocation == nil)
    }
}
