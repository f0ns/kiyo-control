import KiyoKit
import SwiftUI

typealias K = KiyoProUltra

extension Color {
    static let accentGreen = Color(red: 0.27, green: 0.84, blue: 0.17)
    static let panel = Color(white: 0.09)
    static let border = Color(white: 0.3)
}

enum Format {
    static func zoom(_ v: Int) -> String { String(format: "%.1fX", Double(v) / 100) }
    static func fov(_ zoom: Int) -> String { "\(Int(FieldOfView.degrees(zoom: zoom).rounded()))°" }
    static func degrees(_ v: Int) -> String { "\(v / 3600)°" }
    static func kelvin(_ v: Int) -> String { "\(v)K" }
    /// Exposure time is in 100 µs units.
    static func shutter(_ v: Int) -> String {
        v >= 10_000 ? String(format: "%.1fS", Double(v) / 10_000) : "1/\(Int((10_000 / Double(max(v, 1))).rounded()))S"
    }
}

/// Collapsible section header with an optional on/off switch and reset button, like Synapse.
struct SettingsSection<Content: View>: View {
    let title: String
    var toggle: Binding<Bool>? = nil
    var onReset: (() -> Void)? = nil
    @ViewBuilder let content: Content
    @State private var expanded = true

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Button { withAnimation(.snappy) { expanded.toggle() } } label: {
                    Image(systemName: "chevron.down").rotationEffect(.degrees(expanded ? 0 : -90))
                    Text(title.uppercased()).font(.system(size: 14, weight: .medium))
                }
                .buttonStyle(.plain)
                if let toggle {
                    Toggle("", isOn: toggle).toggleStyle(.switch).tint(.accentGreen).labelsHidden()
                }
                if let onReset {
                    Button(action: onReset) { Image(systemName: "arrow.counterclockwise") }
                        .buttonStyle(.plain)
                        .help("Reset to camera defaults")
                }
                Spacer()
            }
            if expanded { content }
        }
        .padding(.vertical, 14)
        .overlay(alignment: .bottom) { Divider() }
    }
}

/// Slider bound to an integer UVC control, with a formatted value label.
struct ControlSlider: View {
    @ObservedObject var model: CameraModel
    let control: UVCControl
    var label: String? = nil
    var format: (Int) -> String = { "\($0)" }
    var minLabel: String? = nil
    var maxLabel: String? = nil
    var disabled = false

    var body: some View {
        let r = model.range(control) ?? UVCRange(min: 0, max: 1, step: 1, defaultValue: 0)
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label ?? control.name)
                Text(format(model.value(control))).foregroundStyle(.secondary).monospacedDigit()
                Spacer()
                if model.value(control) != r.defaultValue {
                    Button("Default") { model.set(control, r.defaultValue) }
                        .buttonStyle(.plain).font(.caption).foregroundStyle(.secondary)
                }
            }
            Slider(value: Binding(get: { Double(model.value(control)) },
                                  set: { model.set(control, Int($0.rounded())) }),
                   in: Double(r.min)...Double(max(r.max, r.min + 1)),
                   step: Double(r.step))
            .tint(.accentGreen)
            if minLabel != nil || maxLabel != nil {
                HStack {
                    Text(minLabel ?? "")
                    Spacer()
                    Text(maxLabel ?? "")
                }
                .font(.caption).foregroundStyle(.secondary)
            }
        }
        .disabled(disabled)
        .opacity(disabled ? 0.4 : 1)
    }
}

/// Row of bordered option buttons, the selected one outlined in green.
struct OptionButtons<Value: Hashable>: View {
    let title: String?
    let options: [(Value, String)]
    let selection: Value?
    var onSelect: (Value) -> Void = { _ in }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let title { Text(title) }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 84), spacing: 8)], alignment: .leading, spacing: 8) {
                ForEach(options, id: \.0) { value, label in
                    Button { onSelect(value) } label: {
                        Text(label)
                            .frame(maxWidth: .infinity, minHeight: 30)
                            .overlay(RoundedRectangle(cornerRadius: 3)
                                .stroke(value == selection ? Color.accentGreen : .border, lineWidth: value == selection ? 2 : 1))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

/// Option buttons for a Razer setting. Nothing is selected while the setting is unknown
/// (the camera can't be asked), so an untouched Synapse setting is left alone.
struct RazerOptions<Value: Hashable>: View {
    @ObservedObject var model: CameraModel
    let title: String?
    let options: [(Value, String)]
    let keyPath: WritableKeyPath<RazerSettings, Value?>

    var body: some View {
        OptionButtons(title: title, options: options, selection: model.razer[keyPath: keyPath]) { v in
            model.setRazer { $0[keyPath: keyPath] = v }
        }
    }
}

/// A Synapse feature that needs Razer's vendor protocol (Phase 2). Shown, but not usable yet.
struct PendingFeature<Value: Hashable>: View {
    let title: String
    let options: [(Value, String)]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            OptionButtons(title: title, options: options, selection: nil)
                .disabled(true)
                .opacity(0.35)
            Text("Not supported yet").font(.caption2).foregroundStyle(.tertiary)
        }
    }
}
