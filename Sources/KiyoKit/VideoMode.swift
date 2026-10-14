import Foundation

/// A resolution and frame rate the camera can stream. Each app that opens the camera picks its own,
/// so this only sets Kiyo Control's preview (Synapse's resolution setting works the same way).
public struct VideoMode: Hashable, Sendable {
    public let width: Int
    public let height: Int
    public let fps: Int

    public init(width: Int, height: Int, fps: Int) {
        self.width = width
        self.height = height
        self.fps = fps
    }

    /// A format as the camera reports it. Frame rates are inexact (30 fps comes as 30.00003).
    public struct Format: Sendable {
        public let width: Int
        public let height: Int
        public let frameRates: [Double]

        public init(width: Int, height: Int, frameRates: [Double]) {
            self.width = width
            self.height = height
            self.frameRates = frameRates
        }
    }

    public var label: String { (height >= 2160 ? "4K" : "\(height)p") + " \(fps)FPS" }

    /// Each size and rate once, largest size first, then fastest.
    public static func options(_ formats: [Format]) -> [VideoMode] {
        let modes = Set(formats.flatMap { f in
            f.frameRates.map { VideoMode(width: f.width, height: f.height, fps: Int($0.rounded())) }
        })
        return modes.sorted { ($0.width * $0.height, $0.fps) > ($1.width * $1.height, $1.fps) }
    }

    /// The saved choice if the camera still offers it, else the largest size at 30 fps, like Synapse.
    public static func preferred(_ options: [VideoMode], saved: VideoMode?) -> VideoMode? {
        if let saved, options.contains(saved) { return saved }
        return options.first { $0.fps == 30 } ?? options.first
    }

    /// For UserDefaults: "1920x1080@30".
    public var stored: String { "\(width)x\(height)@\(fps)" }

    public init?(_ stored: String) {
        let parts = stored.split(whereSeparator: { $0 == "x" || $0 == "@" }).compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        self.init(width: parts[0], height: parts[1], fps: parts[2])
    }
}
