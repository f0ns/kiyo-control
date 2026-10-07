import KiyoKit
import SwiftUI

struct ImageTab: View {
    @ObservedObject var model: CameraModel

    var body: some View {
        SettingsSection(title: "Image", onReset: {
            model.resetToDefault([K.brightness, K.contrast, K.saturation, K.sharpness])
        }) {
            ControlSlider(model: model, control: K.brightness)
            ControlSlider(model: model, control: K.contrast)
            ControlSlider(model: model, control: K.saturation)
            ControlSlider(model: model, control: K.sharpness)
        }
        SettingsSection(title: "Auto White Balance", toggle: Binding(
            get: { model.isAuto(K.autoWhiteBalance) }, set: { model.set(K.autoWhiteBalance, $0 ? 1 : 0) })) {
            ControlSlider(model: model, control: K.whiteBalance, label: "Temperature", format: Format.kelvin,
                          minLabel: "WARM", maxLabel: "COOL", disabled: model.isAuto(K.autoWhiteBalance))
        }
        SettingsSection(title: "Mirror Video") {
            RazerOptions(model: model, title: nil, options: [(false, "Off"), (true, "On")], keyPath: \.mirror)
        }
        SettingsSection(title: "Anti-Flicker") {
            OptionButtons(title: nil, options: [(0, "Off"), (1, "50 Hz"), (2, "60 Hz")],
                          selection: model.value(K.antiFlicker)) { model.set(K.antiFlicker, $0) }
            Text("Match your mains frequency: 50 Hz in Europe, 60 Hz in North America.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}
