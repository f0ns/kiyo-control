import KiyoKit
import SwiftUI

/// Save / Revert, a Synapse-style summary of the active settings, and the preview switch.
struct BottomBar: View {
    @ObservedObject var model: CameraModel
    @ObservedObject var preview: PreviewController

    var body: some View {
        HStack(spacing: 16) {
            Button("SAVE") { model.save() }
                .buttonStyle(.borderedProminent)
                .tint(.accentGreen)
                .disabled(!model.isDirty)
                .keyboardShortcut("s")
            Button("Revert") { model.revert() }
                .disabled(!model.isDirty)
                .help("Go back to the last saved settings of this profile")
            Text(summary).monospacedDigit().foregroundStyle(.secondary)
            Spacer()
            Toggle("PREVIEW", isOn: $preview.enabled).toggleStyle(.switch).tint(.accentGreen)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var summary: String {
        guard model.connected else { return "Connect your Kiyo Pro Ultra" }
        var parts = [preview.formatLabel, Format.zoom(model.value(K.zoom)), "FOV \(Format.fov(model.value(K.zoom)))"]
        if model.isAuto(K.autoExposure) {
            parts.append("AE")
        } else {
            parts += ["GAIN \(model.value(K.gain))", "SS \(Format.shutter(model.value(K.exposureTime)))"]
        }
        parts.append(model.isAuto(K.autoWhiteBalance) ? "AWB" : Format.kelvin(model.value(K.whiteBalance)))
        return parts.filter { !$0.isEmpty }.joined(separator: "   ")
    }
}
