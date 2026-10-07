/// A single value inside a UVC control. Most controls hold one value, but some
/// (like PanTilt) pack several, so a value is addressed by offset and size.
public struct UVCControl: Hashable, Identifiable, Sendable {
    public enum Kind: Sendable { case range, toggle, choice([Int: String]) }

    public let id: String
    public let name: String
    public let unit: UInt8
    public let selector: UInt8
    /// Total wLength of the control on the wire.
    public let length: Int
    /// Byte offset and size of this value within the control.
    public let offset: Int
    public let size: Int
    public let signed: Bool
    public let kind: Kind
    /// Id of an auto toggle that must be off before this value can be set.
    public let manualOnlyWhenOff: String?

    public init(id: String, name: String, unit: UInt8, selector: UInt8, length: Int,
                offset: Int = 0, size: Int? = nil, signed: Bool = false,
                kind: Kind = .range, manualOnlyWhenOff: String? = nil) {
        self.id = id
        self.name = name
        self.unit = unit
        self.selector = selector
        self.length = length
        self.offset = offset
        self.size = size ?? length
        self.signed = signed
        self.kind = kind
        self.manualOnlyWhenOff = manualOnlyWhenOff
    }

    public static func == (a: Self, b: Self) -> Bool { a.id == b.id }
    public func hash(into h: inout Hasher) { h.combine(id) }
}

public enum UVCRequest: UInt8, Sendable {
    case setCur = 0x01, getCur = 0x81, getMin = 0x82, getMax = 0x83
    case getRes = 0x84, getLen = 0x85, getInfo = 0x86, getDef = 0x87
}

public struct UVCRange: Codable, Equatable, Sendable {
    public var min: Int
    public var max: Int
    public var step: Int
    public var defaultValue: Int

    public init(min: Int, max: Int, step: Int, defaultValue: Int) {
        self.min = min
        self.max = max
        self.step = step
        self.defaultValue = defaultValue
    }
}
