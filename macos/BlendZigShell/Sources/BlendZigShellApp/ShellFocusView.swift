import BlendZigShellCore
import SwiftUI

struct ShellFocusView: View {
    @Bindable var model: ShellAppModel

    var body: some View {
        GroupBox("Object Focus") {
            if model.focusTargets.isEmpty {
                Text(emptyMessage)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(model.focusTargets) { target in
                            Button(action: { model.focusTarget(id: target.id) }) {
                                HStack(alignment: .top, spacing: 10) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(target.name)
                                            .font(.headline)
                                        Text("\(target.kind) • \(target.summary)")
                                            .font(.footnote)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer(minLength: 0)
                                }
                                .padding(10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(selectionBackground(for: target), in: RoundedRectangle(cornerRadius: 10))
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if let focusedTarget = model.focusedTarget {
                        Divider()
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Focused Properties")
                                .font(.headline)
                            ForEach(focusedTarget.properties, id: \.label) { property in
                                LabeledContent(property.label) {
                                    Text(property.value)
                                        .textSelection(.enabled)
                                }
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var emptyMessage: String {
        if model.currentRequest?.kind == .bundle {
            return "Bundles stay inspect-only in the current object-focus slice."
        }
        return "Open or create a `.bzrecipe` or `.bzscene` to focus one object or scene part."
    }

    private func selectionBackground(for target: ShellFocusTarget) -> Color {
        if target.id == model.focusedTarget?.id {
            return Color.accentColor.opacity(0.14)
        } else {
            return Color.secondary.opacity(0.08)
        }
    }
}
