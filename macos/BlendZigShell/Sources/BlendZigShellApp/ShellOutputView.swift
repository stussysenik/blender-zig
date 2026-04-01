import SwiftUI

struct ShellOutputView: View {
    let model: ShellAppModel

    var body: some View {
        GroupBox("Helper Output") {
            if let result = model.currentResult {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        outputSection(title: "Standard Output", text: result.standardOutput)
                        if !result.standardError.isEmpty {
                            outputSection(title: "Standard Error", text: result.standardError)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                Text("The shell shows replay output from the bundled helper after a document opens.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func outputSection(title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)
            Text(text.isEmpty ? "(empty)" : text)
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
