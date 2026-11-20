import KiyoKit
import SwiftUI

/// Every USB camera plugged in, with what the app can do with it: connected, switch to it,
/// not responding, a Razer model not supported yet, or not a Kiyo.
struct CameraListView: View {
    @ObservedObject var model: CameraModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if model.cameras.isEmpty {
                Label("No USB cameras found. Plug the Kiyo straight into the Mac.", systemImage: "cable.connector.slash")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(model.cameras) { CameraRow(model: model, camera: $0) }
            }
            Divider()
            HStack(alignment: .firstTextBaseline) {
                Text("Supported: " + KiyoDevice.all.map(\.name).formatted(.list(type: .and)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
                Button("Check Again") { model.poll() }
                    .help("Look for cameras and try to connect again")
            }
        }
    }
}

private struct CameraRow: View {
    @ObservedObject var model: CameraModel
    let camera: USBCamera

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(iconColor)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 3) {
                Text(camera.name)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if camera.status == .unsupportedRazer {
                    Link("Help add it…", destination: CameraDiscovery.supportRequestURL(for: camera))
                        .font(.caption)
                        .help("Opens a GitHub issue with this camera's USB id. Adding a model needs its UVC descriptors.")
                }
            }
            Spacer()
            if isConnected {
                Text("Connected").foregroundStyle(Color.accentGreen)
            } else if camera.device != nil, model.connected || !isChosen {
                Button("Use") { model.select(camera) }
            }
        }
        .opacity(camera.status == .other ? 0.5 : 1)
    }

    private var isConnected: Bool { model.connected && camera.locationID == model.controller.cameraLocation }

    /// The camera the app tries to connect to when it isn't connected.
    private var isChosen: Bool {
        CameraDiscovery.choose(model.cameras, preferring: CameraModel.preferredLocation)?.locationID == camera.locationID
    }

    private var detail: String {
        switch camera.status {
        case .supported:
            if isConnected || model.connected { return "\(camera.usbID) · \(camera.link.name)" }
            return isChosen ? "Not responding. Unplug it and plug it back in." : camera.usbID
        case .unsupportedRazer: return "\(camera.usbID) · not supported yet"
        case .other: return "Not a Kiyo"
        }
    }

    private var icon: String {
        switch camera.status {
        case .supported: isConnected ? "checkmark.circle.fill" : "web.camera"
        case .unsupportedRazer: "exclamationmark.triangle.fill"
        case .other: "web.camera"
        }
    }

    private var iconColor: Color {
        switch camera.status {
        case .supported: isConnected ? .accentGreen : .primary
        case .unsupportedRazer: .yellow
        case .other: .secondary
        }
    }
}

/// Shown in the settings panel while no camera is connected, in place of the disabled controls.
struct NoCameraCard: View {
    @ObservedObject var model: CameraModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("NO KIYO CONNECTED").font(.system(size: 14, weight: .medium))
            CameraListView(model: model)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 6).stroke(Color.border))
        .padding(.vertical, 20)
    }
}

extension CameraModel {
    /// Bottom bar text while disconnected: names an unsupported Razer camera, so the reason is visible at a glance.
    var disconnectedTitle: String {
        if !supportedCameras.isEmpty { return "Kiyo not responding" }
        if let razer = cameras.first(where: { $0.status == .unsupportedRazer }) { return "\(razer.name) not supported" }
        return "Connect your Kiyo"
    }
}

/// Menu items to switch between supported cameras. Only shown when two or more are plugged in.
struct CameraPicker: View {
    @ObservedObject var model: CameraModel

    var body: some View {
        if model.supportedCameras.count > 1 {
            Divider()
            Text("Camera")
            ForEach(model.supportedCameras) { camera in
                Toggle("\(camera.name) (\(camera.link.name))", isOn: Binding(
                    get: { camera.locationID == model.controller.cameraLocation },
                    set: { if $0 { model.select(camera) } }))
            }
        }
    }
}
