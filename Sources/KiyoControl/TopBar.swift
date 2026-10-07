import KiyoKit
import SwiftUI

/// Profile picker, profile/backup menu, tab switcher and Reset All Settings.
struct TopBar: View {
    @ObservedObject var model: CameraModel
    @Binding var tab: Tab
    @State private var confirmReset = false
    @State private var newProfileName = ""
    @State private var askingName = false
    @State private var pendingProfile: String?

    var body: some View {
        let c = model.controller
        HStack(spacing: 12) {
            Picker("Profile", selection: Binding(get: { c.activeProfile }, set: { name in
                if model.isDirty { pendingProfile = name } else { model.switchProfile(name) }
            })) {
                ForEach(c.profileNames, id: \.self) { Text($0).tag($0) }
            }
            .labelsHidden()
            .frame(width: 220)

            Menu {
                Button("New Profile…") { newProfileName = ""; askingName = true }
                Button("Delete Profile", role: .destructive) { model.deleteActiveProfile() }
                    .disabled(c.profileNames.count < 2)
                Divider()
                Menu("Restore Backup") {
                    ForEach(c.backups) { b in
                        Button("\(b.profile.savedAt.formatted(date: .abbreviated, time: .standard)) · \(b.profile.name)") {
                            model.restore(b)
                        }
                    }
                }
                .disabled(c.backups.isEmpty || !c.connected)
                Button("Show Backups in Finder") { model.revealBackups() }
            } label: { Image(systemName: "ellipsis") }
            .menuStyle(.borderlessButton)
            .fixedSize()

            Spacer()
            Picker("Tab", selection: $tab) {
                ForEach(Tab.allCases, id: \.self) { Text($0.rawValue.uppercased()).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 330)
            Spacer()

            Button("Reset All Settings") { confirmReset = true }
                .buttonStyle(.link)
                .disabled(!c.connected)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .confirmationDialog("Reset all settings to the camera's factory defaults?", isPresented: $confirmReset) {
            Button("Reset All Settings", role: .destructive) { model.resetAll() }
        } message: {
            Text("A backup of the current settings is saved first, so you can restore it.")
        }
        .confirmationDialog("Discard unsaved changes?",
                            isPresented: Binding(get: { pendingProfile != nil }, set: { if !$0 { pendingProfile = nil } })) {
            Button("Discard and Switch", role: .destructive) {
                if let p = pendingProfile { model.switchProfile(p) }
            }
        }
        .alert("New Profile", isPresented: $askingName) {
            TextField("Name", text: $newProfileName)
            Button("Create") { model.createProfile(newProfileName) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Saves the current settings as a new profile.")
        }
    }
}
