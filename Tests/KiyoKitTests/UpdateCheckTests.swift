import Foundation
import Testing
@testable import KiyoKit

@Suite struct UpdateCheckTests {
    @Test func comparesVersionsNumerically() {
        #expect(AppVersion("0.10.0")! > AppVersion("0.9.1")!)
        #expect(AppVersion("1.0")! == AppVersion("1.0.0")!)
        #expect(AppVersion("0.2.0")! < AppVersion("0.2.1")!)
    }

    @Test func acceptsTagsWithLeadingV() {
        #expect(AppVersion("v0.3.0") == AppVersion("0.3.0"))
    }

    @Test func rejectsNonVersions() {
        #expect(AppVersion("") == nil)
        #expect(AppVersion("latest") == nil)
        #expect(AppVersion("1.x") == nil)
    }

    @Test func parsesLatestReleaseFromGitHub() throws {
        let json = #"{"tag_name": "v0.3.0", "html_url": "https://github.com/f0ns/kiyo-control/releases/tag/v0.3.0", "draft": false}"#
        let release = try Release.decode(Data(json.utf8))
        #expect(release.version == AppVersion("0.3.0"))
        #expect(release.url.absoluteString == "https://github.com/f0ns/kiyo-control/releases/tag/v0.3.0")
    }

    @Test func offersOnlyNewerReleases() throws {
        let release = Release(version: AppVersion("0.3.0")!, url: URL(string: "https://example.com")!)
        #expect(UpdateCheck.available(release, current: "0.2.0") == release)
        #expect(UpdateCheck.available(release, current: "0.3.0") == nil)
        #expect(UpdateCheck.available(release, current: "0.4.0") == nil)
    }

    @Test func skipsCheckWithoutKnownCurrentVersion() {
        let release = Release(version: AppVersion("0.3.0")!, url: URL(string: "https://example.com")!)
        #expect(UpdateCheck.available(release, current: nil) == nil)
    }

    @Test func respectsSkippedVersion() {
        let release = Release(version: AppVersion("0.3.0")!, url: URL(string: "https://example.com")!)
        #expect(UpdateCheck.available(release, current: "0.2.0", skipped: "0.3.0") == nil)
        let newer = Release(version: AppVersion("0.4.0")!, url: URL(string: "https://example.com")!)
        #expect(UpdateCheck.available(newer, current: "0.2.0", skipped: "0.3.0") == newer)
    }

    @Test func checksAtMostOncePerDay() {
        let now = Date()
        #expect(UpdateCheck.isDue(lastCheck: nil, now: now))
        #expect(!UpdateCheck.isDue(lastCheck: now.addingTimeInterval(-3600), now: now))
        #expect(UpdateCheck.isDue(lastCheck: now.addingTimeInterval(-25 * 3600), now: now))
    }
}
