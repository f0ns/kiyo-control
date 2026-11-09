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
                .help(model.supportsRazer
                    ? "Saves this profile. Razer settings are also stored in the camera, so they stick without the app."
                    : "Saves this profile. Kiyo Control re-applies it when the camera is plugged in.")
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
            if showsUSB2Hint {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.yellow)
                    Text("USB 2")
                }
                .foregroundStyle(Color(white: 0.7))
                .help(Self.usb2Hint)
            }
            Menu {
                if showsUSB2Hint {
                    Text(Self.usb2Hint)
                    Divider()
                }
                ForEach(preview.modes, id: \.self) { mode in
                    Toggle(mode.label, isOn: Binding(get: { preview.mode == mode }, set: { if $0 { preview.select(mode) } }))
                }
            } label: {
                Text(preview.formatLabel.uppercased()).monospacedDigit()
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .disabled(preview.modes.isEmpty)
            .help("Resolution and frame rate of this preview. Zoom, Teams, OBS and other apps choose their own when they turn the camera on.")
            Toggle("PREVIEW", isOn: $preview.enabled).toggleStyle(.switch).tint(.accentGreen)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.surface)
    }

    /// Only for cameras that can stream 4K: a 1080p camera loses nothing it could offer over USB 2.
    private var showsUSB2Hint: Bool { model.link?.limits4K == true && model.supports4K }

    static let usb2Hint = "Connected over USB 2 (e.g. through a keyboard or monitor hub). Plug the camera into a USB 3 port for 4K."

    private var summary: String {
        guard model.connected else { return "Connect your Kiyo" }
        var parts = [Format.zoom(model.value(K.zoom)), model.supportsRazer ? "FOV \(Format.fov(model.value(K.zoom)))" : ""]
        if model.isAuto(K.autoExposure) {
            parts.append("AE")
        } else if model.supportsRazer {
            if let iso = model.razer.iso { parts.append("ISO \(iso)") }
            if let us = model.razer.shutterMicroseconds { parts.append("SS 1/\(1_000_000 / us)S") }
        } else {
            parts.append("SS \(Format.shutter(model.value(K.exposureTime)))")
            parts.append("GAIN \(model.value(K.gain))")
        }
        parts.append(model.isAuto(K.autoWhiteBalance) ? "AWB" : Format.kelvin(model.value(K.whiteBalance)))
        return parts.filter { !$0.isEmpty }.joined(separator: "   ")
    }
}
