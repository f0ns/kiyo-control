import Foundation
import Testing
@testable import KiyoKit

@Suite struct ProfileStoreTests {
    let dir = FileManager.default.temporaryDirectory.appending(path: "kiyo-tests-\(UUID().uuidString)")

    @Test func savesAndLoadsProfiles() throws {
        let store = ProfileStore(root: dir)
        try store.save(Profile(name: "Streaming", values: ["zoom": 200]))
        try store.save(Profile(name: "calls", values: ["zoom": 100]))
        #expect(store.profileNames() == ["calls", "Streaming"])
        #expect(store.profile(named: "Streaming")?.values == ["zoom": 200])
    }

    @Test func remembersActiveProfile() {
        ProfileStore(root: dir).activeProfileName = "Streaming"
        #expect(ProfileStore(root: dir).activeProfileName == "Streaming")
    }

    @Test func keepsOnlyNewestBackups() throws {
        let store = ProfileStore(root: dir, maxBackups: 3)
        for i in 1...5 {
            try store.backup(["zoom": i], reason: "test\(i)")
            Thread.sleep(forTimeInterval: 1.05)  // backups are named and ordered by second
        }
        #expect(store.backups().map { $0.profile.values["zoom"] } == [5, 4, 3])
    }

    @Test func profileNamesWithSlashesAreSafe() throws {
        let store = ProfileStore(root: dir)
        try store.save(Profile(name: "a/b", values: [:]))
        #expect(store.profile(named: "a/b") != nil)
    }
}
