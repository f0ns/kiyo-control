import Foundation

/// A dotted version number like "0.2.0" (a leading "v", as in git tags, is ignored).
public struct AppVersion: Comparable, Hashable, Sendable, CustomStringConvertible {
    /// Numbers without trailing zeros, so 1.0 and 1.0.0 are equal.
    public let parts: [Int]

    public init?(_ string: String) {
        let s = string.hasPrefix("v") ? string.dropFirst() : Substring(string)
        let numbers = s.split(separator: ".", omittingEmptySubsequences: false).map { Int($0) }
        guard !numbers.isEmpty, numbers.allSatisfy({ $0 != nil }) else { return nil }
        var parts = numbers.compactMap { $0 }
        while parts.count > 1, parts.last == 0 { parts.removeLast() }
        self.parts = parts
    }

    public var description: String { (parts + Array(repeating: 0, count: max(0, 3 - parts.count))).map(String.init).joined(separator: ".") }

    public static func < (a: AppVersion, b: AppVersion) -> Bool {
        for i in 0..<max(a.parts.count, b.parts.count) {
            let x = i < a.parts.count ? a.parts[i] : 0, y = i < b.parts.count ? b.parts[i] : 0
            if x != y { return x < y }
        }
        return false
    }
}

/// A published GitHub release.
public struct Release: Equatable, Sendable {
    public let version: AppVersion
    /// The release page, where users download the zip.
    public let url: URL

    public init(version: AppVersion, url: URL) {
        self.version = version
        self.url = url
    }

    /// Decodes the response of GitHub's "latest release" API (which skips drafts and pre-releases).
    public static func decode(_ data: Data) throws -> Release {
        struct Payload: Decodable { let tag_name: String; let html_url: URL }
        let p = try JSONDecoder().decode(Payload.self, from: data)
        guard let version = AppVersion(p.tag_name) else {
            throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Not a version tag: \(p.tag_name)"))
        }
        return Release(version: version, url: p.html_url)
    }
}

/// Decides whether to tell the user about a new release on GitHub.
public enum UpdateCheck {
    public static let latestReleaseAPI = URL(string: "https://api.github.com/repos/f0ns/kiyo-control/releases/latest")!
    public static let interval: TimeInterval = 24 * 3600

    /// The release, if it is newer than the running version and not skipped by the user.
    /// Without a known current version (e.g. `swift run`, no app bundle) nothing is offered.
    public static func available(_ release: Release, current: String?, skipped: String? = nil) -> Release? {
        guard let current = current.flatMap(AppVersion.init), release.version > current else { return nil }
        if let skipped = skipped.flatMap(AppVersion.init), release.version <= skipped { return nil }
        return release
    }

    public static func isDue(lastCheck: Date?, now: Date = Date()) -> Bool {
        guard let lastCheck else { return true }
        return now.timeIntervalSince(lastCheck) >= interval
    }

    /// Fetches the latest release from GitHub.
    public static func fetchLatest(session: URLSession = .shared) async throws -> Release {
        var request = URLRequest(url: latestReleaseAPI, timeoutInterval: 15)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 { throw URLError(.badServerResponse) }
        return try Release.decode(data)
    }
}
