/// Razer-specific settings of the Kiyo Pro Ultra. They are 8-byte commands written to selector 1 of
/// extension unit 6 (GUID 23e49ed0-1178-4f31-ae52-d2fb8a8d3b48). Byte layouts come from USB captures
/// of Synapse, documented in https://github.com/soyersoyer/cameractrls/issues/19.
///
/// The NVRAM save command (c0 03 a8) is deliberately not exposed.
public enum RazerCommand {
    public static let unit: UInt8 = 6
    public static let commandSelector: UInt8 = 1
    public static let resultSelector: UInt8 = 2

    public enum Metering: Int, CaseIterable, Codable, Sendable {
        case average = 0, center = 1, face = 5
    }

    public static let isoSteps = [100, 200, 400, 800, 1600, 3200, 6400]

    public static func mirror(_ on: Bool) -> [UInt8] { cmd(0xC0, 0x0E, 0x03, on ? 1 : 0) }
    public static func noiseReduction3D(_ on: Bool) -> [UInt8] { cmd(0xC0, 0x0E, 0x01, on ? 1 : 0) }
    public static func noiseReduction2D(_ on: Bool) -> [UInt8] { cmd(0xC0, 0x0E, 0x02, on ? 1 : 0) }
    public static func metering(_ m: Metering) -> [UInt8] { cmd(0xC0, 0x0E, 0x04, UInt8(m.rawValue)) }

    /// Exposure compensation in tenths of a stop, -30...30 (-3.0 to +3.0 EV).
    public static func exposureCompensation(_ tenths: Int) -> [UInt8] {
        cmd(0xC0, 0x0E, 0x05, UInt8(min(max(tenths, -30), 30) + 30))
    }

    /// Manual ISO, one of `isoSteps`.
    public static func iso(_ value: Int) -> [UInt8] {
        let index = isoSteps.firstIndex(of: value) ?? 0
        return cmd(0xC0, 0x09, 0x01, UInt8(index + 1))
    }

    /// Manual shutter time in microseconds (500 = 1/2000 s ... 100000 = 1/10 s), big-endian in bytes 4-6.
    public static func shutter(microseconds: Int) -> [UInt8] {
        let v = min(max(microseconds, 500), 100_000)
        return [0xC0, 0x09, 0x05, 0x00, UInt8(v >> 16 & 0xFF), UInt8(v >> 8 & 0xFF), UInt8(v & 0xFF), 0x00]
    }

    /// Autofocus mode (Standard/Face) and lighting (Standard/Stylized) are one command.
    public static func focus(face: Bool, stylized: Bool) -> [UInt8] {
        [0xC0, 0x0A, 0x01, face ? 1 : 0, 0, 0, 0, stylized ? 1 : 0]
    }

    public static func tracking(responsive: Bool) -> [UInt8] { cmd(0xFF, 0x06, responsive ? 0 : 1) }

    /// Lens distortion compensation. Takes effect when the video stream restarts.
    public static func lensCorrection(_ on: Bool) -> [UInt8] { cmd(0xFF, 0x01, on ? 1 : 0, 0x03) }

    private static func cmd(_ bytes: UInt8...) -> [UInt8] {
        bytes + [UInt8](repeating: 0, count: 8 - bytes.count)
    }
}

extension UVCCamera {
    /// Sends a Razer command and returns the camera's reply from the result register.
    @discardableResult
    public func send(_ command: [UInt8]) throws -> [UInt8] {
        try rawSet(unit: RazerCommand.unit, selector: RazerCommand.commandSelector, bytes: command)
        return (try? raw(.getCur, unit: RazerCommand.unit, selector: RazerCommand.resultSelector, length: 8)) ?? []
    }
}
