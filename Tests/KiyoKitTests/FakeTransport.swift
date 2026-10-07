@testable import KiyoKit

/// In-memory UVC device: stores bytes per (unit, selector) and records every SET.
final class FakeTransport: UVCTransport {
    struct Key: Hashable { let unit: UInt8, selector: UInt8 }

    var current: [Key: [UInt8]] = [:]
    var minimum: [Key: [UInt8]] = [:]
    var maximum: [Key: [UInt8]] = [:]
    var defaults: [Key: [UInt8]] = [:]
    var failing: Set<Key> = []
    var setLog: [Key] = []
    var writes: [[UInt8]] = []

    func request(_ request: UVCRequest, unit: UInt8, selector: UInt8, data: inout [UInt8]) throws {
        let key = Key(unit: unit, selector: selector)
        if failing.contains(key) { throw UVCError(code: -1, context: "fake") }
        switch request {
        case .setCur:
            current[key] = data
            setLog.append(key)
            writes.append(data)
            return
        case .getCur: data = current[key] ?? data
        case .getMin: data = minimum[key] ?? data
        case .getMax: data = maximum[key] ?? data
        case .getDef: data = defaults[key] ?? data
        case .getRes: data = [1] + [UInt8](repeating: 0, count: max(0, data.count - 1))
        default: throw UVCError(code: -1, context: "unsupported")
        }
    }

    func key(_ c: UVCControl) -> Key { Key(unit: c.unit, selector: c.selector) }

    /// Little-endian bytes for a control value.
    static func bytes(_ value: Int, size: Int) -> [UInt8] {
        let v = UInt64(bitPattern: Int64(value))
        return (0..<size).map { UInt8(truncatingIfNeeded: v >> (8 * $0)) }
    }

    func stub(_ c: UVCControl, cur: Int, min: Int = 0, max: Int = 255, def: Int = 0) {
        let k = key(c)
        current[k] = Self.bytes(cur, size: c.length)
        minimum[k] = Self.bytes(min, size: c.length)
        maximum[k] = Self.bytes(max, size: c.length)
        defaults[k] = Self.bytes(def, size: c.length)
    }
}
