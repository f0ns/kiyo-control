import Foundation

/// Profiles and automatic backups on disk, under ~/Library/Application Support/KiyoControl.
public final class ProfileStore {
    public let root: URL
    public let maxBackups: Int
    private var profilesDir: URL { root.appending(path: "profiles") }
    private var backupsDir: URL { root.appending(path: "backups") }
    private var stateFile: URL { root.appending(path: "state.json") }

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        e.dateEncodingStrategy = .iso8601
        return e
    }()
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    public init(root: URL? = nil, maxBackups: Int = 20) {
        self.root = root ?? URL.applicationSupportDirectory.appending(path: "KiyoControl")
        self.maxBackups = maxBackups
        for dir in [profilesDir, backupsDir] {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
    }

    // MARK: Profiles

    public func profileNames() -> [String] {
        let files = (try? FileManager.default.contentsOfDirectory(at: profilesDir, includingPropertiesForKeys: nil)) ?? []
        return files.filter { $0.pathExtension == "json" }
            .compactMap { load($0)?.name }
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    public func profile(named name: String) -> Profile? { load(profileURL(name)) }

    public func save(_ profile: Profile) throws {
        try write(profile, to: profileURL(profile.name))
    }

    public func deleteProfile(named name: String) throws {
        try FileManager.default.removeItem(at: profileURL(name))
    }

    public var activeProfileName: String? {
        get { (try? decoder.decode([String: String].self, from: Data(contentsOf: stateFile)))?["activeProfile"] }
        set { try? encoder.encode(["activeProfile": newValue ?? ""]).write(to: stateFile, options: .atomic) }
    }

    // MARK: Backups

    public struct Backup: Identifiable {
        public let url: URL
        public let profile: Profile
        public var id: URL { url }
    }

    public static let connectReason = "on-connect"

    /// Stores a timestamped snapshot. Connect backups identical to the previous one are skipped, and
    /// connect backups are pruned separately so frequent replugs never push out other backups.
    @discardableResult
    public func backup(_ values: [String: Int], razer: RazerSettings = RazerSettings(), reason: String) throws -> URL {
        let existing = backups()
        if reason == Self.connectReason,
           let last = existing.first(where: { $0.profile.name == reason }),
           last.profile.values == values, last.profile.razer == razer {
            return last.url
        }
        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let url = backupsDir.appending(path: "\(stamp) \(reason) \(UUID().uuidString.prefix(6)).json")
        try write(Profile(name: reason, values: values, razer: razer), to: url)

        let all = backups()
        let connects = all.filter { $0.profile.name == Self.connectReason }
        let others = all.filter { $0.profile.name != Self.connectReason }
        for old in connects.dropFirst(maxBackups) + others.dropFirst(maxBackups) {
            try? FileManager.default.removeItem(at: old.url)
        }
        return url
    }

    /// Backups, newest first.
    public func backups() -> [Backup] {
        let files = (try? FileManager.default.contentsOfDirectory(at: backupsDir, includingPropertiesForKeys: nil)) ?? []
        return files.filter { $0.pathExtension == "json" }
            .compactMap { url in load(url).map { Backup(url: url, profile: $0) } }
            .sorted { $0.profile.savedAt > $1.profile.savedAt }
    }

    // MARK: Helpers

    private func profileURL(_ name: String) -> URL {
        let safe = name.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-")
        return profilesDir.appending(path: "\(safe).json")
    }

    private func load(_ url: URL) -> Profile? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? decoder.decode(Profile.self, from: data)
    }

    private func write(_ profile: Profile, to url: URL) throws {
        try encoder.encode(profile).write(to: url, options: .atomic)
    }
}
