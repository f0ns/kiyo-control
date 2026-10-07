/// Control map for the Razer Kiyo Pro Ultra (USB 1532:0E08), taken from its
/// UVC descriptors: Camera Terminal id 1, Processing Unit id 3, VideoControl interface 0.
public enum KiyoProUltra {
    public static let vendorID: UInt16 = 0x1532
    public static let productID: UInt16 = 0x0E08
    public static let interface: UInt8 = 0

    static let ct: UInt8 = 1
    static let pu: UInt8 = 3

    // Camera Terminal
    public static let autoExposure = UVCControl(
        id: "autoExposure", name: "Auto Exposure", unit: ct, selector: 0x02, length: 1,
        kind: .choice([1: "Manual", 8: "Auto"]))
    public static let exposureTime = UVCControl(
        id: "exposureTime", name: "Shutter Speed", unit: ct, selector: 0x04, length: 4,
        manualOnlyWhenOff: "autoExposure")
    public static let autoFocus = UVCControl(
        id: "autoFocus", name: "Auto Focus", unit: ct, selector: 0x08, length: 1, kind: .toggle)
    public static let focus = UVCControl(
        id: "focus", name: "Focus", unit: ct, selector: 0x06, length: 2, manualOnlyWhenOff: "autoFocus")
    public static let zoom = UVCControl(
        id: "zoom", name: "Zoom", unit: ct, selector: 0x0B, length: 2)
    public static let pan = UVCControl(
        id: "pan", name: "Pan", unit: ct, selector: 0x0D, length: 8, offset: 0, size: 4, signed: true)
    public static let tilt = UVCControl(
        id: "tilt", name: "Tilt", unit: ct, selector: 0x0D, length: 8, offset: 4, size: 4, signed: true)

    // Processing Unit
    public static let brightness = UVCControl(
        id: "brightness", name: "Brightness", unit: pu, selector: 0x02, length: 2, signed: true)
    public static let contrast = UVCControl(
        id: "contrast", name: "Contrast", unit: pu, selector: 0x03, length: 2)
    public static let saturation = UVCControl(
        id: "saturation", name: "Saturation", unit: pu, selector: 0x07, length: 2)
    public static let sharpness = UVCControl(
        id: "sharpness", name: "Sharpness", unit: pu, selector: 0x08, length: 2)
    public static let autoWhiteBalance = UVCControl(
        id: "autoWhiteBalance", name: "Auto White Balance", unit: pu, selector: 0x0B, length: 1, kind: .toggle)
    public static let whiteBalance = UVCControl(
        id: "whiteBalance", name: "White Balance", unit: pu, selector: 0x0A, length: 2,
        manualOnlyWhenOff: "autoWhiteBalance")
    public static let backlight = UVCControl(
        id: "backlight", name: "Backlight Compensation", unit: pu, selector: 0x01, length: 2)
    public static let gain = UVCControl(
        id: "gain", name: "Gain", unit: pu, selector: 0x04, length: 2, manualOnlyWhenOff: "autoExposure")
    public static let antiFlicker = UVCControl(
        id: "antiFlicker", name: "Anti-Flicker", unit: pu, selector: 0x05, length: 1,
        kind: .choice([0: "Off", 1: "50 Hz", 2: "60 Hz"]))

    /// All controls in a safe apply order: auto toggles come before the values they gate.
    public static let all: [UVCControl] = [
        antiFlicker, autoExposure, exposureTime, gain, autoFocus, focus, zoom, pan, tilt,
        brightness, contrast, saturation, sharpness, autoWhiteBalance, whiteBalance, backlight,
    ]

    public static func control(_ id: String) -> UVCControl? { all.first { $0.id == id } }
}
