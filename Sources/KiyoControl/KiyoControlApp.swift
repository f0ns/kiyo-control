import KiyoKit
import ServiceManagement
import SwiftUI

extension Notification.Name {
    static let openMainWindow = Notification.Name("openMainWindow")
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    /// True when macOS started the app at login: stay in the menu bar without opening the window.
    private(set) var launchedAtLogin = false

    func applicationWillFinishLaunching(_ notification: Notification) {
        let event = NSAppleEventManager.shared().currentAppleEvent
        launchedAtLogin = event?.paramDescriptor(forKeyword: keyAELaunchedAsLogInItem)?.booleanValue == true
    }

    /// Clicking the Dock icon or opening the app again shows the window.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        if !hasVisibleWindows { NotificationCenter.default.post(name: .openMainWindow, object: nil) }
        return true
    }

    /// Closing the window keeps the app running in the menu bar, so settings keep being applied.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}

@main
struct KiyoControlApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    /// Lives as long as the app, so the camera is managed even with the window closed.
    @StateObject private var model = CameraModel()

    init() {
        // KIYO_SELFTEST=1 repeatedly runs the main-actor isolation check SwiftUI relies on (see scripts/smoke.sh).
        if ProcessInfo.processInfo.environment["KIYO_SELFTEST"] != nil {
            Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in MainActor.assumeIsolated {} }
        }
        // KIYO_SNAPSHOT=<file.png> saves a picture of the window after launch and quits (for checking the UI).
        if let path = ProcessInfo.processInfo.environment["KIYO_SNAPSHOT"] {
            Timer.scheduledTimer(withTimeInterval: 4, repeats: false) { _ in
                MainActor.assumeIsolated {
                    if let view = NSApp.windows.first(where: { $0.isVisible && $0.contentView != nil })?.contentView,
                       let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) {
                        view.cacheDisplay(in: view.bounds, to: rep)
                        try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: path))
                    }
                    NSApp.terminate(nil)
                }
            }
        }
    }

    var body: some Scene {
        Window("Kiyo Control", id: "main") {
            ContentView(model: model)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .defaultLaunchBehavior(.suppressed)

        MenuBarExtra {
            MenuBarMenu(model: model)
        } label: {
            MenuBarLabel(connected: model.connected, launchedAtLogin: appDelegate.launchedAtLogin)
        }
    }
}

/// The menu bar icon. Also opens the window at launch (unless started at login) and on reopen.
struct MenuBarLabel: View {
    let connected: Bool
    let launchedAtLogin: Bool
    @Environment(\.openWindow) private var openWindow
    @State private var didLaunch = false

    var body: some View {
        Image(systemName: connected ? "web.camera.fill" : "web.camera")
            .task {
                guard !didLaunch else { return }
                didLaunch = true
                if !launchedAtLogin { open() }
            }
            .onReceive(NotificationCenter.default.publisher(for: .openMainWindow)) { _ in open() }
    }

    private func open() {
        openWindow(id: "main")
        NSApp.activate()
    }
}

struct MenuBarMenu: View {
    @ObservedObject var model: CameraModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        let c = model.controller
        Text(c.connected ? "\(c.device.name) connected" : "Kiyo not connected")
        Divider()
        ForEach(c.profileNames, id: \.self) { name in
            Toggle(name, isOn: Binding(get: { c.activeProfile == name }, set: { if $0 { model.switchProfile(name) } }))
        }
        if c.connected, model.zoomPresets.contains(where: { $0 != nil }) {
            Divider()
            Text("Zoom Presets")
            ForEach(0..<ZoomPreset.slots, id: \.self) { slot in
                if let preset = model.zoomPresets[slot] {
                    Button("\(slot + 1) · \(Format.zoom(preset.zoom)) · \(Format.fov(preset.zoom))") { model.applyZoomPreset(slot) }
                }
            }
        }
        Divider()
        Button("Open Kiyo Control…") {
            openWindow(id: "main")
            NSApp.activate()
        }
        Link("Donate…", destination: Links.donate)
        Toggle("Launch at Login", isOn: Binding(get: { LaunchAtLogin.isEnabled }, set: { LaunchAtLogin.isEnabled = $0 }))
        Divider()
        Button("Quit Kiyo Control") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}

enum LaunchAtLogin {
    static var isEnabled: Bool {
        get { SMAppService.mainApp.status == .enabled }
        set {
            do {
                if newValue { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            } catch {
                NSLog("Launch at login: \(error)")
            }
        }
    }
}
