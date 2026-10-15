import Foundation
import IOKit
import IOUSBHost

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

/// UVC requests over the USB default pipe via Apple's IOUSBHost framework. Opens the device
/// without capturing it, so other apps (and the system camera driver) keep streaming.
public final class USBTransport: UVCTransport {
    private let device: IOUSBHostDevice
    private let interface: UInt8

    public init?(vendorID: UInt16, productID: UInt16, interface: UInt8) {
        let matching = IOServiceMatching("IOUSBHostDevice") as NSMutableDictionary
        matching["idVendor"] = Int(vendorID)
        matching["idProduct"] = Int(productID)
        let service = IOServiceGetMatchingService(kIOMainPortDefault, matching as CFDictionary)
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }
        guard let device = try? IOUSBHostDevice(__ioService: service, options: [], queue: nil, interestHandler: nil) else {
            return nil
        }
        self.device = device
        self.interface = interface
    }

    deinit { device.destroy() }

    public func request(_ request: UVCRequest, unit: UInt8, selector: UInt8, data: inout [UInt8]) throws {
        var r = IOUSBDeviceRequest()
        r.bmRequestType = request == .setCur ? 0x21 : 0xA1  // class request to an interface, out / in
        r.bRequest = request.rawValue
        r.wValue = UInt16(selector) << 8
        r.wIndex = UInt16(unit) << 8 | UInt16(interface)
        r.wLength = UInt16(data.count)
        let buffer = NSMutableData(bytes: data, length: data.count)
        var done = 0
        do {
            try device.__send(r, data: buffer, bytesTransferred: &done, completionTimeout: 1.0)
        } catch {
            throw UVCError(code: Int32(truncatingIfNeeded: (error as NSError).code), context: "\(request) unit \(unit) selector \(selector)")
        }
        if request != .setCur { data = [UInt8](Data(referencing: buffer).prefix(done)) }
    }
}

/// Typed access to UVC controls.
public final class UVCCamera {
    private let transport: UVCTransport
    public let device: KiyoDevice

    public init(transport: UVCTransport, device: KiyoDevice = .proUltra) {
        self.transport = transport
        self.device = device
    }

    /// Connects to a supported Kiyo over USB. Returns nil if none is plugged in.
    public convenience init?() {
        for device in KiyoDevice.all {
            if let usb = USBTransport(vendorID: device.vendorID, productID: device.productID, interface: device.interface) {
                self.init(transport: usb, device: device)
                return
            }
        }
        return nil
    }

    /// Controls are declared with the Pro Ultra's Processing Unit id. Other models use a different id, so we swap it here.
    private func unit(_ c: UVCControl) -> UInt8 { c.unit == KiyoProUltra.pu ? device.processingUnit : c.unit }

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
        decode(try raw(request, unit: unit(c), selector: c.selector, length: c.length), c)
    }

    public func set(_ c: UVCControl, _ value: Int) throws {
        var bytes: [UInt8]
        if c.size == c.length {
            bytes = [UInt8](repeating: 0, count: c.length)
        } else {
            // Packed control: keep the other values as they are.
            bytes = try raw(.getCur, unit: unit(c), selector: c.selector, length: c.length)
        }
        let v = UInt64(bitPattern: Int64(value))
        for i in 0..<c.size { bytes[c.offset + i] = UInt8(truncatingIfNeeded: v >> (8 * i)) }
        try transport.request(.setCur, unit: unit(c), selector: c.selector, data: &bytes)
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
