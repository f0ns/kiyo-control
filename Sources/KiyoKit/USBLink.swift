import Foundation
import IOKit

/// The USB connection the camera negotiated. On a USB 2 link (e.g. a keyboard's hub) the
/// Kiyo offers at most 1080p; 4K needs USB 3. Also carries the firmware version the camera
/// reports in its USB device descriptor.
public struct USBLink: Equatable, Sendable {
    public let bitsPerSecond: Int
    /// Firmware version, e.g. "1.02", or nil if the camera did not report one.
    public let firmware: String?
    /// The USB version the camera itself supports (descriptor bcdUSB, e.g. 0x0201), or nil if unknown.
    public let usbVersion: Int?

    public init(bitsPerSecond: Int, firmware: String? = nil, usbVersion: Int? = nil) {
        self.bitsPerSecond = bitsPerSecond
        self.firmware = firmware
        self.usbVersion = usbVersion
    }

    /// True when a USB 3 camera runs on a slower link. A USB 2 camera (e.g. the Kiyo V2 X) is
    /// always on a USB 2 link, and a USB 3 port would not change that.
    public var limits4K: Bool { bitsPerSecond < 5_000_000_000 && (usbVersion ?? 0x0300) >= 0x0300 }
    public var name: String { bitsPerSecond < 5_000_000_000 ? "USB 2" : "USB 3" }

    /// Formats the descriptor's bcdDevice: binary-coded decimal, 0x0102 is version 1.02.
    static func firmwareVersion(bcd: Int) -> String {
        String(format: "%X.%02X", (bcd >> 8) & 0xFF, bcd & 0xFF)
    }

    /// The link of the plugged-in Kiyo (any supported model), or nil when none is connected.
    public static func current() -> USBLink? {
        for device in KiyoDevice.all {
            if let link = current(vendorID: device.vendorID, productID: device.productID) { return link }
        }
        return nil
    }

    static func current(vendorID: UInt16, productID: UInt16) -> USBLink? {
        let matching = IOServiceMatching("IOUSBHostDevice") as NSMutableDictionary
        matching["idVendor"] = Int(vendorID)
        matching["idProduct"] = Int(productID)
        let service = IOServiceGetMatchingService(kIOMainPortDefault, matching as CFDictionary)
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }
        func property(_ key: String) -> NSNumber? {
            IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0)?
                .takeRetainedValue() as? NSNumber
        }
        guard let speed = property("UsbLinkSpeed") else { return nil }
        return USBLink(bitsPerSecond: speed.intValue, firmware: property("bcdDevice").map { firmwareVersion(bcd: $0.intValue) },
                       usbVersion: property("bcdUSB")?.intValue)
    }
}
