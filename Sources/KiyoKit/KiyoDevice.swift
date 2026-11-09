import Foundation

/// A supported camera model. All models use the same control ids. Only the USB ids and the
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
    /// True if the camera can stream 4K. The "plug into USB 3 for 4K" hint only makes sense for these.
    public let supports4K: Bool

    public init(name: String, vendorID: UInt16, productID: UInt16, interface: UInt8, processingUnit: UInt8,
                razerCommands: Bool, firmwareUpdater: URL?, supports4K: Bool = true) {
        self.name = name
        self.vendorID = vendorID
        self.productID = productID
        self.interface = interface
        self.processingUnit = processingUnit
        self.razerCommands = razerCommands
        self.firmwareUpdater = firmwareUpdater
        self.supports4K = supports4K
    }

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

    /// Kiyo Pro (the original 1080p model), USB 1532:0E05. Same unit ids as the Pro Ultra: Camera
    /// Terminal 1, Processing Unit 3, VideoControl interface 0. Its two extension units (GUIDs
    /// 2c49d16a-32b8-4485-3ea8-643a152362f2 and 23e49ed0-1178-4f31-ae52-d2fb8a8d3b48) differ from the
    /// Pro Ultra's and are not documented, so the app only supports the standard UVC controls.
    public static let kiyoPro = KiyoDevice(
        name: "Kiyo Pro", vendorID: 0x1532, productID: 0x0E05, interface: 0,
        processingUnit: 3, razerCommands: false, firmwareUpdater: nil, supports4K: false)

    public static let all: [KiyoDevice] = [proUltra, v2Pro, kiyoPro]
}
