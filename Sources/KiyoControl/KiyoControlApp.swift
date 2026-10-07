import SwiftUI

@main
struct KiyoControlApp: App {
    init() {
        // KIYO_SELFTEST=1 repeatedly runs the main-actor isolation check SwiftUI relies on (see scripts/smoke.sh).
        if ProcessInfo.processInfo.environment["KIYO_SELFTEST"] != nil {
            Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in MainActor.assumeIsolated {} }
        }
    }

    var body: some Scene {
        Window("Kiyo Control", id: "main") {
            ContentView()
        }
    }
}
