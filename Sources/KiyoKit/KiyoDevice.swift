import Foundation

/// A supported camera model. Both models use the same control ids. Only the USB ids and the
/// Processing Unit id differ (the Processing Unit id comes from the camera's UVC descriptors).
public struct KiyoDevice: Sendable, Equatable {
    public let name: String
    public let vendorID: UInt16
    public let productID: UInt16
    public let interface: UInt8
    public let processingUnit: UInt8
    /// True if we know the Razer extension unit commands (`RazerCommand`) for this camera.
    public let razerCommands: Bool
    /// Razer's firmware updater page (Windows only). Nil hides the firmware version and link in the
    /// app: only the Pro Ultra's is supported. The app itself never updates firmware.
    public let firmwareUpdater: URL?

    /// Kiyo Pro Ultra, USB 1532:0E08.
    public static let proUltra = KiyoDevice(
        name: "Kiyo Pro Ultra", vendorID: 0x1532, productID: 0x0E08, interface: 0,
        processingUnit: KiyoProUltra.pu, razerCommands: true,
        firmwareUpdater: URL(string: "https://mysupport.razer.com/app/answers/detail/a_id/9777"))

    /// Kiyo V2 Pro, USB 1532:0E0A. Its extension unit (GUID 455a4152-5f52-5355-4243-414d5f455854) is
    /// not documented, so the app only supports the standard UVC controls.
    public static let v2Pro = KiyoDevice(
        name: "Kiyo V2 Pro", vendorID: 0x1532, productID: 0x0E0A, interface: 0,
        processingUnit: 2, razerCommands: false, firmwareUpdater: nil)

    public static let all: [KiyoDevice] = [proUltra, v2Pro]
}
