import KiyoKit
import SwiftUI

/// Save / Revert, a Synapse-style summary of the active settings, and the preview switch.
struct BottomBar: View {
    @ObservedObject var model: CameraModel
    @ObservedObject var preview: PreviewController

    var body: some View {
        HStack(spacing: 16) {
            Button("SAVE") { model.save() }
                .buttonStyle(GreenButtonStyle())
                .disabled(!model.isDirty)
                .keyboardShortcut("s")
                .help("Saves this profile. Razer settings are also stored in the camera, so they stick without the app.")
            Button("Revert") { model.revert() }
                .disabled(!model.isDirty)
                .help("Go back to the last saved settings of this profile")
            Text(summary.uppercased()).monospacedDigit().foregroundStyle(Color(white: 0.85))
            Spacer()
            Link(destination: Links.donate) {
                HStack(spacing: 4) {
                    Image(systemName: "heart.fill")
                    Text("Donate")
                }
            }
            .foregroundStyle(Color(white: 0.7))
            .help("Kiyo Control is free. If it helps you, consider a donation.")
            Toggle("PREVIEW", isOn: $preview.enabled).toggleStyle(.switch).tint(.accentGreen)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.surface)
    }

    private var summary: String {
        guard model.connected else { return "Connect your Kiyo Pro Ultra" }
        var parts = [preview.formatLabel, Format.zoom(model.value(K.zoom)), "FOV \(Format.fov(model.value(K.zoom)))"]
        if model.isAuto(K.autoExposure) {
            parts.append("AE")
        } else {
            if let iso = model.razer.iso { parts.append("ISO \(iso)") }
            if let us = model.razer.shutterMicroseconds { parts.append("SS 1/\(1_000_000 / us)S") }
        }
        parts.append(model.isAuto(K.autoWhiteBalance) ? "AWB" : Format.kelvin(model.value(K.whiteBalance)))
        return parts.filter { !$0.isEmpty }.joined(separator: "   ")
    }
}
