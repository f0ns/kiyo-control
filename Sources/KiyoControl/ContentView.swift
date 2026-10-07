import KiyoKit
import SwiftUI

enum Tab: String, CaseIterable { case camera = "Camera", processing = "Processing", image = "Image" }

struct ContentView: View {
    @StateObject private var model = CameraModel()
    @StateObject private var preview = PreviewController()
    @State private var tab = Tab.camera

    var body: some View {
        let c = model.controller
        VStack(spacing: 0) {
            TopBar(model: model, tab: $tab)
            Divider()
            HStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        switch tab {
                        case .camera: CameraTab(model: model)
                        case .processing: ProcessingTab(model: model)
                        case .image: ImageTab(model: model)
                        }
                    }
                    .padding(.horizontal, 20)
                    .disabled(!model.connected)
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
        .preferredColorScheme(.dark)
        .frame(minWidth: 1000, minHeight: 680)
        .onAppear { preview.start() }
    }
}
