import BlendZigShellCore
import SceneKit
import SwiftUI

struct ShellViewportView: View {
    let model: ShellAppModel

    @State private var preview: ShellViewportPreview?
    @State private var previewError: String?

    var body: some View {
        GroupBox("Viewport MVP") {
            VStack(alignment: .leading, spacing: 12) {
                header

                if let preview {
                    SceneView(
                        scene: preview.scene,
                        pointOfView: preview.cameraNode,
                        options: [.allowsCameraControl, .autoenablesDefaultLighting]
                    )
                    .frame(minHeight: 360)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    placeholder
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .task(id: previewTaskID) {
            await loadPreview()
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                if let preview {
                    Text(preview.artifact.geometryURL.lastPathComponent)
                        .font(.headline)
                    Text(preview.artifact.geometryURL.path)
                        .font(.system(.footnote, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                } else {
                    Text("Preview the helper-backed OBJ output for one saved recipe or scene.")
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 0)

            Button("Reset Camera", systemImage: "arrow.counterclockwise", action: resetCamera)
                .disabled(preview == nil)
        }
    }

    private var placeholder: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(previewMessage)
                .foregroundStyle(.secondary)
            if let previewError {
                Text(previewError)
                    .foregroundStyle(.red)
                    .textSelection(.enabled)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 240, alignment: .topLeading)
        .padding(16)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }

    private var previewTaskID: String {
        if let result = model.currentResult {
            return "\(result.request.url.path)|\(result.exitCode)|\(result.standardOutput)"
        }
        return "empty"
    }

    private var previewMessage: String {
        if model.currentResult == nil {
            return "Open a `.bzrecipe` or `.bzscene` to build a viewport preview from the existing helper replay."
        }

        if let request = model.currentRequest, request.kind == .bundle {
            return "Bundles stay inspect-only in the current viewport launch slice."
        }

        return "The current replay did not produce a previewable OBJ surface."
    }

    private func resetCamera() {
        guard let preview else { return }
        ShellViewportPreview.reset(preview)
    }

    @MainActor
    private func loadPreview() async {
        guard let result = model.currentResult else {
            preview = nil
            previewError = nil
            return
        }

        do {
            let loadedPreview = try ShellViewportPreview.load(from: result)
            preview = loadedPreview
            previewError = nil
        } catch {
            preview = nil
            previewError = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
        }
    }
}
