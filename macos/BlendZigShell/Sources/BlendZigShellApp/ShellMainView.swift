import BlendZigShellCore
import SwiftUI

struct ShellMainView: View {
    let model: ShellAppModel
    let launchMode: ShellLaunchMode

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            controls
            HSplitView {
                ShellViewportView(model: model)
                    .frame(minWidth: 460, maxWidth: .infinity)

                VStack(alignment: .leading, spacing: 18) {
                    ShellSummaryView(model: model)
                    ShellFocusView(model: model)
                    ShellEditorView(model: model)
                    ShellOutputView(model: model)
                    Spacer(minLength: 0)
                }
                .frame(minWidth: 320, idealWidth: 360, maxWidth: 420)
            }
        }
        .padding(20)
        .frame(minWidth: 1040, minHeight: 720)
        .task {
            model.openStartupRequestIfNeeded(launchMode)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("blender-zig shell")
                .font(.title2.weight(.semibold))
            Text("Open or create a `.bzrecipe`, replay it through the bundled Zig helper, and keep one bounded object-focused modeling flow inside a native macOS window.")
                .foregroundStyle(.secondary)
        }
    }

    private var controls: some View {
        HStack(spacing: 12) {
            Button("Open Document", systemImage: "folder", action: openDocument)
                .disabled(model.isOpening || model.isSaving)
            Menu("New Primitive", systemImage: "plus.square") {
                ForEach(ShellPrimitiveTemplate.allCases, id: \.self) { template in
                    Button(template.displayName) {
                        createPrimitiveStudy(template)
                    }
                }
            }
            .disabled(model.isOpening || model.isSaving)
            Button("Reload", systemImage: "arrow.clockwise", action: model.reloadCurrentDocument)
                .disabled(model.currentRequest == nil || model.isOpening || model.isSaving)
            if model.isOpening {
                ProgressView("Opening…")
                    .controlSize(.small)
            }
            if model.isSaving {
                ProgressView("Saving…")
                    .controlSize(.small)
            }
        }
    }

    private func openDocument() {
        guard let url = ShellOpenPanel.chooseDocumentURL() else { return }
        model.openDocument(at: url)
    }

    private func createPrimitiveStudy(_ template: ShellPrimitiveTemplate) {
        guard let url = ShellSavePanel.choosePrimitiveStudyURL(for: template) else { return }
        model.createPrimitiveStudy(template: template, at: url)
    }
}
