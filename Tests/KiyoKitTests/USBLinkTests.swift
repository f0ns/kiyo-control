import Testing
@testable import KiyoKit

@Suite struct USBLinkTests {
    @Test func usb2IsTooSlowFor4K() {
        #expect(USBLink(bitsPerSecond: 480_000_000).limits4K)
        #expect(!USBLink(bitsPerSecond: 5_000_000_000).limits4K)
        #expect(!USBLink(bitsPerSecond: 10_000_000_000).limits4K)
    }

    @Test func namesTheLink() {
        #expect(USBLink(bitsPerSecond: 480_000_000).name == "USB 2")
        #expect(USBLink(bitsPerSecond: 5_000_000_000).name == "USB 3")
    }

    @Test func formatsTheBCDFirmwareVersion() {
        #expect(USBLink.firmwareVersion(bcd: 0x0102) == "1.02")
        #expect(USBLink.firmwareVersion(bcd: 0x1010) == "10.10")
        #expect(USBLink.firmwareVersion(bcd: 0x0009) == "0.09")
    }

    @Test func onlyTheProUltraLinksAFirmwareUpdater() {
        #expect(KiyoDevice.proUltra.firmwareUpdater?.absoluteString == "https://mysupport.razer.com/app/answers/detail/a_id/9777")
        #expect(KiyoDevice.v2Pro.firmwareUpdater == nil)
    }

    @Test func readsThePluggedInCameraOrNothing() {
        // No hardware needed: either the camera is there with a real speed, or nil.
        if let link = USBLink.current() { #expect(link.bitsPerSecond >= 480_000_000) }
    }
}
