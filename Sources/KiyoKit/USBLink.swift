import Foundation

/// The USB connection the camera negotiated. On a USB 2 link (e.g. a keyboard's hub) the
/// Kiyo offers at most 1080p; 4K needs USB 3. Also carries the firmware version the camera
/// reports in its USB device descriptor.
public struct USBLink: Equatable, Sendable {
    public let bitsPerSecond: Int
    /// Firmware version, e.g. "1.02", or nil if the camera did not report one.
    public let firmware: String?

    public init(bitsPerSecond: Int, firmware: String? = nil) {
        self.bitsPerSecond = bitsPerSecond
        self.firmware = firmware
    }

    public var limits4K: Bool { bitsPerSecond < 5_000_000_000 }
    public var name: String { limits4K ? "USB 2" : "USB 3" }

    /// Formats the descriptor's bcdDevice: binary-coded decimal, 0x0102 is version 1.02.
    static func firmwareVersion(bcd: Int) -> String {
        String(format: "%X.%02X", (bcd >> 8) & 0xFF, bcd & 0xFF)
    }
}
