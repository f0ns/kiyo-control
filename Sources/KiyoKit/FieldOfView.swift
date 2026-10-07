import Foundation

/// Field of view from the zoom level. The Kiyo Pro Ultra has no field-of-view command; Synapse's
/// FOV follows the digital zoom. The full width is calibrated so 2x zoom gives the 44° Synapse shows.
public enum FieldOfView {
    /// Horizontal field of view at 1x zoom, in degrees.
    public static let fullWidth = 2 * atan(2 * tan(22 * Double.pi / 180)) * 180 / Double.pi

    /// Field of view for a UVC zoom value (100 = 1x).
    public static func degrees(zoom: Int) -> Double {
        let half = fullWidth / 2 * Double.pi / 180
        return 2 * atan(tan(half) / (Double(max(zoom, 1)) / 100)) * 180 / Double.pi
    }

    public enum Preset: CaseIterable, Sendable {
        case wide, medium, narrow

        public var zoom: Int {
            switch self {
            case .wide: 100
            case .medium: 140
            case .narrow: 200
            }
        }

        public var name: String {
            switch self {
            case .wide: "Wide"
            case .medium: "Medium"
            case .narrow: "Narrow"
            }
        }

        public init?(zoom: Int) {
            guard let p = Self.allCases.first(where: { $0.zoom == zoom }) else { return nil }
            self = p
        }
    }
}
