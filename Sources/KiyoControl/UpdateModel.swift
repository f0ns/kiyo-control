import KiyoKit
import SwiftUI

/// Looks for a newer release on GitHub, at most once a day, and remembers what the user skipped.
@MainActor
final class UpdateModel: ObservableObject {
    /// A newer release to tell the user about.
    @Published private(set) var available: Release?
    /// Set after a manual check that found nothing, to confirm the app is current.
    @Published var upToDate = false
    @Published var autoCheck: Bool {
        didSet { defaults.set(autoCheck, forKey: Keys.autoCheck); if autoCheck { checkIfDue() } }
    }

    /// KIYO_VERSION=<x.y.z> pretends to be another version (for checking the banner).
    let currentVersion = ProcessInfo.processInfo.environment["KIYO_VERSION"]
        ?? Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String

    private let defaults = UserDefaults.standard
    private var timer: Timer?
    private enum Keys {
        static let autoCheck = "checkForUpdates", lastCheck = "lastUpdateCheck", skipped = "skippedVersion"
    }

    init() {
        autoCheck = defaults.object(forKey: Keys.autoCheck) as? Bool ?? true
        checkIfDue()
        // The app lives in the menu bar for days, so look again now and then.
        timer = Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.checkIfDue() }
        }
    }

    func checkIfDue() {
        guard autoCheck, UpdateCheck.isDue(lastCheck: defaults.object(forKey: Keys.lastCheck) as? Date) else { return }
        check(manual: false)
    }

    /// A manual check also shows a skipped version again, and confirms when there is nothing new.
    func check(manual: Bool) {
        Task {
            let release: Release
            do {
                release = try await UpdateCheck.fetchLatest()
            } catch {
                NSLog("Update check: \(error)")
                return
            }
            defaults.set(Date(), forKey: Keys.lastCheck)
            let skipped = manual ? nil : defaults.string(forKey: Keys.skipped)
            available = UpdateCheck.available(release, current: currentVersion, skipped: skipped)
            upToDate = manual && available == nil
        }
    }

    func download() {
        if let available { NSWorkspace.shared.open(available.url) }
        available = nil
    }

    /// Hides this version for good; a later one is still offered.
    func skip() {
        if let available { defaults.set(available.version.description, forKey: Keys.skipped) }
        available = nil
    }

    /// Hides the notice until the next check.
    func dismiss() {
        available = nil
        upToDate = false
    }
}

/// Strip under the title when a new version is out, in the app's green-on-dark style.
struct UpdateBanner: View {
    @ObservedObject var updates: UpdateModel

    var body: some View {
        if let release = updates.available {
            bar {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.down.circle.fill").foregroundStyle(Color.accentGreen)
                    Text("VERSION \(release.version.description) AVAILABLE")
                        .font(.system(size: 13, weight: .medium)).tracking(0.6)
                }
                Text("You have \(updates.currentVersion ?? "?")").foregroundStyle(.secondary)
                Spacer()
                Button("Skip This Version") { updates.skip() }
                    .buttonStyle(.plain).foregroundStyle(Color(white: 0.75))
                Button("DOWNLOAD") { updates.download() }
                    .buttonStyle(GreenButtonStyle())
                    .help("Opens the release page on GitHub")
            }
        } else if updates.upToDate {
            bar {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.accentGreen)
                    Text("KIYO CONTROL \(updates.currentVersion ?? "") IS UP TO DATE")
                        .font(.system(size: 13, weight: .medium)).tracking(0.6)
                }
                Spacer()
            }
        }
    }

    private func bar<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        HStack(spacing: 12) {
            content()
            Button { updates.dismiss() } label: { Image(systemName: "xmark") }
                .buttonStyle(.plain).foregroundStyle(.secondary)
                .help("Hide")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.panel)
        .overlay(alignment: .leading) { Rectangle().fill(Color.accentGreen).frame(width: 3) }
        .overlay(alignment: .bottom) { Divider() }
    }
}
