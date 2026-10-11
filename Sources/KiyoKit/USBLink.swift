import Foundation
import IOKit

/// The USB connection the camera negotiated. On a USB 2 link (e.g. a keyboard's hub) the
/// Kiyo Pro Ultra offers at most 1080p; 4K needs USB 3.
public struct USBLink: Equatable, Sendable {
    public let bitsPerSecond: Int

    public init(bitsPerSecond: Int) { self.bitsPerSecond = bitsPerSecond }

    public var limits4K: Bool { bitsPerSecond < 5_000_000_000 }
    public var name: String { limits4K ? "USB 2" : "USB 3" }

    /// The link of the plugged-in Kiyo Pro Ultra, or nil when it isn't connected.
    public static func current(vendorID: UInt16 = KiyoProUltra.vendorID, productID: UInt16 = KiyoProUltra.productID) -> USBLink? {
        let matching = IOServiceMatching("IOUSBHostDevice") as NSMutableDictionary
        matching["idVendor"] = Int(vendorID)
        matching["idProduct"] = Int(productID)
        let service = IOServiceGetMatchingService(kIOMainPortDefault, matching as CFDictionary)
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }
        let speed = IORegistryEntryCreateCFProperty(service, "UsbLinkSpeed" as CFString, kCFAllocatorDefault, 0)?
            .takeRetainedValue() as? NSNumber
        return speed.map { USBLink(bitsPerSecond: $0.intValue) }
    }
}
