import KiyoKit
import SwiftUI

struct CameraTab: View {
    @ObservedObject var model: CameraModel

    /// Synapse's shutter steps, as 1/x seconds.
    static let shutterDivisors = [2000, 1600, 1280, 1000, 800, 640, 500, 400, 320, 250, 200, 160, 120, 100,
                                  90, 75, 60, 50, 48, 40, 33, 30, 25, 24, 20, 17, 16, 15, 13, 12, 11, 10]

    var body: some View {
        SettingsSection(title: "Zoom", onReset: { model.resetToDefault([K.zoom, K.pan, K.tilt]) }) {
            ControlSlider(model: model, control: K.zoom, format: { "\(Format.zoom($0)) · \(Format.fov($0))" })
            ControlSlider(model: model, control: K.pan, format: Format.degrees, minLabel: "LEFT", maxLabel: "RIGHT")
            ControlSlider(model: model, control: K.tilt, format: Format.degrees, minLabel: "DOWN", maxLabel: "UP")
            zoomPresets
        }
        SettingsSection(title: "Field of View") {
            OptionButtons(title: nil,
                          options: FieldOfView.Preset.allCases.map { ($0, "\($0.name) \(Format.fov($0.zoom))") },
                          selection: FieldOfView.Preset(zoom: model.value(K.zoom))) { model.set(K.zoom, $0.zoom) }
            Text("Sets the zoom; the camera has no separate field-of-view setting.")
                .font(.caption).foregroundStyle(.secondary)
        }
        SettingsSection(title: "Auto Focus", toggle: autoBinding(K.autoFocus, on: 1, off: 0)) {
            ControlSlider(model: model, control: K.focus, label: "Manual focus",
                          minLabel: "NEAR", maxLabel: "FAR", disabled: model.isAuto(K.autoFocus))
            RazerOptions(model: model, title: "Mode", options: [(false, "Standard"), (true, "Face")], keyPath: \.faceFocus)
            RazerOptions(model: model, title: "Tracking", options: [(false, "Passive"), (true, "Responsive")],
                         keyPath: \.responsiveTracking)
            RazerOptions(model: model, title: "Lighting", options: [(false, "Standard"), (true, "Stylized")],
                         keyPath: \.stylizedLighting)
        }
        SettingsSection(title: "Auto Exposure", toggle: autoBinding(K.autoExposure, on: 8, off: 1),
                        onReset: { model.resetToDefault([K.autoExposure]) }) {
            if model.isAuto(K.autoExposure) {
                RazerOptions(model: model, title: "Metering",
                             options: [(.average, "Average"), (.center, "Center"), (.face, "Face")], keyPath: \.metering)
                compensation
            } else {
                RazerOptions(model: model, title: "ISO", options: RazerCommand.isoSteps.map { ($0, "\($0)") }, keyPath: \.iso)
                shutter
            }
        }
    }

    private var zoomPresets: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Presets")
            HStack(spacing: 8) {
                ForEach(0..<ZoomPreset.slots, id: \.self) { slot in
                    let preset = model.zoomPresets[slot]
                    let active = preset.map { $0 == ZoomPreset(zoom: model.value(K.zoom), pan: model.value(K.pan),
                                                               tilt: model.value(K.tilt)) } ?? false
                    Button { model.applyZoomPreset(slot) } label: {
                        Text("\(slot + 1)")
                            .frame(maxWidth: .infinity, minHeight: 30)
                            .foregroundStyle(preset == nil ? .tertiary : .primary)
                            .overlay(RoundedRectangle(cornerRadius: 3)
                                .stroke(active ? Color.accentGreen : .border, lineWidth: active ? 2 : 1))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help(preset.map { "\(Format.zoom($0.zoom)) · \(ZoomPresetHotKeys.label)\(slot + 1)" } ?? "Empty: right-click to store the current view")
                    .contextMenu {
                        Button("Store Current View in \(slot + 1)") { model.storeZoomPreset(slot) }
                    }
                }
            }
            Text("Right-click a number to store the current view. Shortcut: \(ZoomPresetHotKeys.label)1–5, from any app.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private var compensation: some View {
        let tenths = model.razer.exposureCompensation ?? 0
        let low = model.razer.metering == .face ? -10 : -30
        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Compensation")
                Text(String(format: "%+.1f EV", Double(tenths) / 10)).foregroundStyle(.secondary).monospacedDigit()
            }
            Slider(value: Binding(get: { Double(tenths) },
                                  set: { v in model.setRazer { $0.exposureCompensation = Int(v.rounded()) } }),
                   in: Double(low)...30, step: 1)
            .tint(.accentGreen)
        }
    }

    private var shutter: some View {
        let divs = Self.shutterDivisors
        let current = model.razer.shutterMicroseconds.map { us in
            divs.indices.min { abs(1_000_000 / divs[$0] - us) < abs(1_000_000 / divs[$1] - us) } ?? 16
        } ?? divs.firstIndex(of: 60)!
        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Shutter speed")
                Text(model.razer.shutterMicroseconds == nil ? "–" : "1/\(divs[current])S")
                    .foregroundStyle(.secondary).monospacedDigit()
            }
            Slider(value: Binding(get: { Double(current) },
                                  set: { i in model.setRazer { $0.shutterMicroseconds = 1_000_000 / divs[Int(i.rounded())] } }),
                   in: 0...Double(divs.count - 1), step: 1)
            .tint(.accentGreen)
            HStack { Text("FAST"); Spacer(); Text("SLOW") }.font(.caption).foregroundStyle(.secondary)
        }
    }

    private func autoBinding(_ c: UVCControl, on: Int, off: Int) -> Binding<Bool> {
        Binding(get: { model.isAuto(c) }, set: { model.set(c, $0 ? on : off) })
    }
}

struct ProcessingTab: View {
    @ObservedObject var model: CameraModel

    var body: some View {
        SettingsSection(title: "Noise Reduction") {
            RazerOptions(model: model, title: "3D (between frames)", options: [(false, "Off"), (true, "On")],
                         keyPath: \.noiseReduction3D)
            RazerOptions(model: model, title: "2D (within a frame)", options: [(false, "Off"), (true, "On")],
                         keyPath: \.noiseReduction2D)
        }
        SettingsSection(title: "Low Light") {
            Toggle("Backlight compensation", isOn: Binding(
                get: { model.value(K.backlight) != 0 }, set: { model.set(K.backlight, $0 ? 1 : 0) }))
            .toggleStyle(.switch).tint(.accentGreen)
        }
        SettingsSection(title: "Lens Distortion Compensation") {
            RazerOptions(model: model, title: nil, options: [(false, "Off (82°)"), (true, "On (72°)")],
                         keyPath: \.lensCorrection)
            Text("Straightens lines at the edges. Takes effect after ⋯ › Save to Camera and replugging the camera.")
                .font(.caption).foregroundStyle(.secondary)
        }
        PendingFeature(title: "HDR", options: [(0, "Off"), (1, "On")])
            .padding(.vertical, 14)
    }
}
