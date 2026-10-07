import Foundation

/// A saved set of control values, keyed by control id.
public struct Profile: Codable, Equatable, Sendable {
    public var name: String
    public var values: [String: Int]
    public var razer: RazerSettings
    public var savedAt: Date

    public init(name: String, values: [String: Int], razer: RazerSettings = RazerSettings(), savedAt: Date = Date()) {
        self.name = name
        self.values = values
        self.razer = razer
        self.savedAt = savedAt
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = try c.decode(String.self, forKey: .name)
        values = try c.decode([String: Int].self, forKey: .values)
        // Profiles saved before Razer settings existed have no "razer" key.
        razer = try c.decodeIfPresent(RazerSettings.self, forKey: .razer) ?? RazerSettings()
        savedAt = try c.decode(Date.self, forKey: .savedAt)
    }
}

extension UVCCamera {
    /// Reads every readable control. Unsupported ones are skipped.
    public func snapshot(_ controls: [UVCControl] = KiyoProUltra.all) -> [String: Int] {
        var out: [String: Int] = [:]
        for c in controls { if let v = try? get(c) { out[c.id] = v } }
        return out
    }

    /// Writes values in safe order, clamped to each control's range. Values gated by an
    /// auto toggle are skipped while that toggle is on. Returns the controls that failed.
    @discardableResult
    public func apply(_ values: [String: Int], ranges: [String: UVCRange],
                      controls: [UVCControl] = KiyoProUltra.all) -> [String: Error] {
        var failed: [String: Error] = [:]
        for c in controls {
            guard var v = values[c.id] else { continue }
            if let gate = c.manualOnlyWhenOff, isAuto(gate, values[gate]) { continue }
            if let r = ranges[c.id], case .range = c.kind { v = Swift.min(Swift.max(v, r.min), r.max) }
            do { try set(c, v) } catch { failed[c.id] = error }
        }
        return failed
    }
}

/// Whether an auto toggle's raw value means "auto on".
public func isAuto(_ id: String, _ value: Int?) -> Bool {
    guard let value else { return false }
    return id == KiyoProUltra.autoExposure.id ? value != 1 : value != 0
}

/// Values to compare for "unsaved changes": drops values the camera drives itself while their auto mode is on.
public func comparableValues(_ values: [String: Int], controls: [UVCControl] = KiyoProUltra.all) -> [String: Int] {
    values.filter { id, _ in
        guard let gate = controls.first(where: { $0.id == id })?.manualOnlyWhenOff else { return true }
        return !isAuto(gate, values[gate])
    }
}
