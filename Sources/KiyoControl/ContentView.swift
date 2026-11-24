import KiyoKit
import SwiftUI

enum Tab: String, CaseIterable { case camera = "Camera", processing = "Processing", image = "Image" }

struct ContentView: View {
    @ObservedObject var model: CameraModel
    @ObservedObject var updates: UpdateModel
    @StateObject private var preview = PreviewController()
    @State private var tab = Tab.camera

    var body: some View {
        let c = model.controller
        VStack(spacing: 0) {
            Text("KIYO CONTROL")
                .font(.system(size: 13, weight: .medium))
                .tracking(1.2)
                .foregroundStyle(Color(white: 0.75))
                .frame(maxWidth: .infinity, minHeight: 38)
                .background(Color.chrome)
            UpdateBanner(updates: updates)
            TopBar(model: model, tab: $tab)
            Divider()
            HStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        if !model.connected {
                            NoCameraCard(model: model)
                        } else {
                            switch tab {
                            case .camera: CameraTab(model: model)
                            case .processing: ProcessingTab(model: model)
                            case .image: ImageTab(model: model)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .frame(width: 340)
                .background(Color.panel)
                Divider()
                ZStack {
                    Color.black
                    if preview.enabled { PreviewView(session: preview.session) }
                    if !preview.enabled {
                        Text("Preview off").foregroundStyle(.secondary)
                    } else if !preview.status.isEmpty {
                        Text(preview.status).foregroundStyle(.secondary)
                    }
                    if let error = c.lastError {
                        VStack {
                            Spacer()
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.yellow)
                                Text(error)
                                Button("Dismiss") { model.perform { $0.lastError = nil } }
                            }
                            .padding(10)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                            .padding()
                        }
                    }
                }
            }
            Divider()
            BottomBar(model: model, preview: preview)
        }
        .background(Color.surface)
        .preferredColorScheme(.dark)
        .ignoresSafeArea(edges: .top)
        .frame(minWidth: 1000, minHeight: 680)
        .onAppear { preview.start() }
        // A replug (e.g. moving to a USB 3 port) can change the formats the camera offers.
        .onChange(of: model.connected) { _, connected in
            if connected {
                preview.preferredLocation = model.controller.cameraLocation
                preview.reconnect()
            }
        }
        // Another Kiyo was picked: show its picture. A first connect is handled by the line above.
        .onChange(of: model.controller.cameraLocation) { old, new in
            preview.preferredLocation = new
            if old != nil, new != nil { preview.reconnect() }
        }
        // Release the camera (and its light) when the window closes; the app stays in the menu bar.
        .onDisappear { preview.stop() }
    }
}
