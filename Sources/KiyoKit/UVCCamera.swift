import CUVC

public struct UVCError: Error, CustomStringConvertible {
    public let code: Int32
    public let context: String
    public var description: String { "\(context) failed (IOReturn 0x\(String(UInt32(bitPattern: code), radix: 16)))" }

    /// kIOReturnNoDevice / kIOReturnNotResponding: the camera is gone.
    public var isDisconnected: Bool { code == Int32(bitPattern: 0xE00002C0) || code == Int32(bitPattern: 0xE00002ED) }
}

/// Sends one UVC class request. GET requests fill `data` (its count is wLength); SET_CUR sends it.
public protocol UVCTransport: AnyObject {
    func request(_ request: UVCRequest, unit: UInt8, selector: UInt8, data: inout [UInt8]) throws
}

/// UVC requests over the USB default pipe via IOKit, without claiming the device.
public final class USBTransport: UVCTransport {
    private let handle: OpaquePointer
    private let interface: UInt8

    public init?(vendorID: UInt16, productID: UInt16, interface: UInt8) {
        guard let h = cuvc_open(vendorID, productID) else { return nil }
        handle = h
        self.interface = interface
    }

    deinit { cuvc_close(handle) }

    public func request(_ request: UVCRequest, unit: UInt8, selector: UInt8, data: inout [UInt8]) throws {
        var done: UInt16 = 0
        let length = UInt16(data.count)
        let rc = data.withUnsafeMutableBytes { cuvc_request(handle, request.rawValue, unit, selector, interface, $0.baseAddress, length, &done) }
        guard rc == 0 else { throw UVCError(code: rc, context: "\(request) unit \(unit) selector \(selector)") }
        if request != .setCur { data = Array(data.prefix(Int(done))) }
    }
}

/// Typed access to UVC controls.
public final class UVCCamera {
    private let transport: UVCTransport

    public init(transport: UVCTransport) { self.transport = transport }

    /// Connects to a Kiyo Pro Ultra over USB, or returns nil when it isn't plugged in.
    public convenience init?() {
        guard let usb = USBTransport(vendorID: KiyoProUltra.vendorID, productID: KiyoProUltra.productID,
                                     interface: KiyoProUltra.interface) else { return nil }
        self.init(transport: usb)
    }

    public func raw(_ request: UVCRequest, unit: UInt8, selector: UInt8, length: Int) throws -> [UInt8] {
        var buf = [UInt8](repeating: 0, count: length)
        try transport.request(request, unit: unit, selector: selector, data: &buf)
        return buf
    }

    public func rawSet(unit: UInt8, selector: UInt8, bytes: [UInt8]) throws {
        var data = bytes
        try transport.request(.setCur, unit: unit, selector: selector, data: &data)
    }

    public func get(_ c: UVCControl, _ request: UVCRequest = .getCur) throws -> Int {
        decode(try raw(request, unit: c.unit, selector: c.selector, length: c.length), c)
    }

    public func set(_ c: UVCControl, _ value: Int) throws {
        var bytes: [UInt8]
        if c.size == c.length {
            bytes = [UInt8](repeating: 0, count: c.length)
        } else {
            // Packed control: keep the other values as they are.
            bytes = try raw(.getCur, unit: c.unit, selector: c.selector, length: c.length)
        }
        let v = UInt64(bitPattern: Int64(value))
        for i in 0..<c.size { bytes[c.offset + i] = UInt8(truncatingIfNeeded: v >> (8 * i)) }
        try transport.request(.setCur, unit: c.unit, selector: c.selector, data: &bytes)
    }

    /// Range of a control. Choice/toggle controls have no MIN/MAX in UVC, so they get a synthetic range.
    public func range(_ c: UVCControl) throws -> UVCRange {
        let def = (try? get(c, .getDef)) ?? 0
        switch c.kind {
        case .toggle:
            return UVCRange(min: 0, max: 1, step: 1, defaultValue: def)
        case .choice(let options):
            let keys = options.keys.sorted()
            return UVCRange(min: keys.first ?? 0, max: keys.last ?? 0, step: 1, defaultValue: def)
        case .range:
            return UVCRange(min: try get(c, .getMin), max: try get(c, .getMax),
                            step: max(1, (try? get(c, .getRes)) ?? 1), defaultValue: def)
        }
    }

    private func decode(_ bytes: [UInt8], _ c: UVCControl) -> Int {
        guard bytes.count >= c.offset + c.size else { return 0 }
        var v: UInt64 = 0
        for i in 0..<c.size { v |= UInt64(bytes[c.offset + i]) << (8 * i) }
        if c.signed, c.size < 8, v & (1 << (8 * c.size - 1)) != 0 { v |= ~0 << (8 * c.size) }
        return Int(Int64(bitPattern: v))
    }
}
