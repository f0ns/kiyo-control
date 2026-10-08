import KiyoKit
import SwiftUI

typealias K = KiyoProUltra

enum Links {
    static let donate = URL(string: "https://www.paypal.com/donate/?hosted_button_id=CSFVGLP7FFYMU")!
}

extension Color {
    static let accentGreen = Color(red: 0.27, green: 0.84, blue: 0.17)
    /// Title strip at the very top.
    static let chrome = Color(white: 0.0)
    /// Main window background.
    static let surface = Color(white: 0.13)
    /// Settings panel and cards.
    static let panel = Color(white: 0.08)
    static let border = Color(white: 0.3)
}

/// Uppercase pill tabs; the selected one is filled green.
struct PillTabs<T: Hashable>: View {
    let options: [(T, String)]
    @Binding var selection: T

    var body: some View {
        HStack(spacing: 6) {
            ForEach(options, id: \.0) { value, label in
                let selected = value == selection
                Button { selection = value } label: {
                    Text(label.uppercased())
                        .font(.system(size: 13, weight: .medium))
                        .tracking(0.6)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .foregroundStyle(selected ? Color.black : Color(white: 0.75))
                        .background(Capsule().fill(selected ? Color.accentGreen : .clear))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// Solid green call-to-action button with dark text.
struct GreenButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var enabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .tracking(0.6)
            .foregroundStyle(enabled ? Color.black : Color(white: 0.45))
            .padding(.horizontal, 28)
            .padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 3)
                .fill(enabled ? Color.accentGreen.opacity(configuration.isPressed ? 0.75 : 1) : Color(white: 0.2)))
    }
}

enum Format {
    static func zoom(_ v: Int) -> String { String(format: "%.1fX", Double(v) / 100) }
    static func fov(_ zoom: Int) -> String { "\(Int(FieldOfView.degrees(zoom: zoom).rounded()))°" }
    static func degrees(_ v: Int) -> String { "\(v / 3600)°" }
    /// Exposure time is measured in units of 100 µs.
    static func shutter(_ v: Int) -> String { v > 0 ? "1/\(Int((10_000 / Double(v)).rounded()))S" : "–" }
    static func kelvin(_ v: Int) -> String { "\(v)K" }
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
        if model.supportsRazer {
            OptionButtons(title: title, options: options, selection: model.razer[keyPath: keyPath]) { v in
                model.setRazer { $0[keyPath: keyPath] = v }
            }
        }
    }
}
