import BlendZigShellCore
import SwiftUI

struct ShellEditorView: View {
    @Bindable var model: ShellAppModel

    var body: some View {
        GroupBox("Inspect And Save") {
            VStack(alignment: .leading, spacing: 10) {
                TextField("Document title", text: $model.editableTitle)
                    .textFieldStyle(.roundedBorder)
                    .disabled(!(model.currentInspection?.isEditable ?? false) || model.isSaving || model.isOpening)

                HStack(spacing: 12) {
                    Button("Save Title", systemImage: "square.and.arrow.down", action: saveTitle)
                        .disabled(!model.canSaveCurrentDocument || model.isSaving || model.isOpening)

                    if let inspection = model.currentInspection, !inspection.isEditable {
                        Text("This document is inspect-only in the current shell slice.")
                            .foregroundStyle(.secondary)
                    }
                }

                if let saveMessage = model.saveMessage {
                    Text(saveMessage)
                        .foregroundStyle(.secondary)
                }

                if let transformState = model.recipeTransformState {
                    Divider()
                    transformEditor(transformState: transformState)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func saveTitle() {
        model.saveTitle()
    }

    private func saveRecipeTransform() {
        model.saveRecipeTransform()
    }

    @ViewBuilder
    private func transformEditor(transformState: ShellRecipeTransformState) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Focused Recipe Transform")
                .font(.headline)

            Text("Edit the bounded trailing `scale`, `rotate-z`, and `translate` block for the focused recipe root.")
                .foregroundStyle(.secondary)

            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                GridRow {
                    Text("Scale")
                        .foregroundStyle(.secondary)
                    transformField("X", text: $model.recipeScaleX)
                    transformField("Y", text: $model.recipeScaleY)
                    transformField("Z", text: $model.recipeScaleZ)
                }
                GridRow {
                    Text("Rotate Z")
                        .foregroundStyle(.secondary)
                    transformField("Degrees", text: $model.recipeRotateZDegrees)
                    Color.clear
                    Color.clear
                }
                GridRow {
                    Text("Translate")
                        .foregroundStyle(.secondary)
                    transformField("X", text: $model.recipeTranslateX)
                    transformField("Y", text: $model.recipeTranslateY)
                    transformField("Z", text: $model.recipeTranslateZ)
                }
            }
            .disabled(!transformState.isEditable || model.isSaving || model.isOpening)

            HStack(spacing: 12) {
                Button("Save Transform", systemImage: "move.3d", action: saveRecipeTransform)
                    .disabled(!model.canSaveRecipeTransform || model.isSaving || model.isOpening)

                if let message = transformState.message {
                    Text(message)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func transformField(_ title: String, text: Binding<String>) -> some View {
        TextField(title, text: text)
            .textFieldStyle(.roundedBorder)
            .frame(minWidth: 72)
    }
}
