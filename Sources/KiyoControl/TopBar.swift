import KiyoKit
import SwiftUI

/// Profile picker, profile/backup menu, tab switcher and Reset All Settings.
struct TopBar: View {
    @ObservedObject var model: CameraModel
    @Binding var tab: Tab
    @State private var confirmReset = false
    @State private var confirmCameraSave = false
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
                Button("Save to Camera…") { confirmCameraSave = true }
                    .disabled(!c.connected)
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
            PillTabs(options: Tab.allCases.map { ($0, $0.rawValue) }, selection: $tab)
            Spacer()

            Button { confirmReset = true } label: {
                Text("Reset All Settings").underline()
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color(white: 0.85))
            .disabled(!c.connected)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.surface)
        .confirmationDialog("Reset all settings to the camera's factory defaults?", isPresented: $confirmReset) {
            Button("Reset All Settings", role: .destructive) { model.resetAll() }
        } message: {
            Text("A backup of the current settings is saved first, so you can restore it.")
        }
        .confirmationDialog("Save the Razer settings in the camera?", isPresented: $confirmCameraSave) {
            Button("Save to Camera") { model.saveToCamera() }
        } message: {
            Text("The camera then starts with these Razer settings (ISO, metering, focus, mirror, noise reduction, lens correction), also on other computers, like Synapse's Save. Standard settings such as zoom and brightness are not kept by the camera; Kiyo Control re-applies those from your profile.")
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
