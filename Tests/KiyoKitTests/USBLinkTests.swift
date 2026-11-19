import Testing
@testable import KiyoKit

@Suite struct USBLinkTests {
    @Test func usb2IsTooSlowFor4K() {
        #expect(USBLink(bitsPerSecond: 480_000_000).limits4K)
        #expect(!USBLink(bitsPerSecond: 5_000_000_000).limits4K)
        #expect(!USBLink(bitsPerSecond: 10_000_000_000).limits4K)
    }

    @Test func usb2CameraIsNotLimitedByTheLink() {
        // The Kiyo V2 X is a USB 2 device: a USB 3 port would not help, so no 4K warning.
        #expect(!USBLink(bitsPerSecond: 480_000_000, usbVersion: 0x0201).limits4K)
        #expect(USBLink(bitsPerSecond: 480_000_000, usbVersion: 0x0320).limits4K)
        #expect(!USBLink(bitsPerSecond: 5_000_000_000, usbVersion: 0x0320).limits4K)
        #expect(USBLink(bitsPerSecond: 480_000_000, usbVersion: 0x0201).name == "USB 2")
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
        #expect(KiyoDevice.v2X.firmwareUpdater == nil)
    }

    @Test func readsThePluggedInCameraOrNothing() {
        // No hardware needed: either the camera is there with a real speed, or nil.
        if let link = USBLink.current() { #expect(link.bitsPerSecond >= 480_000_000) }
    }
}
