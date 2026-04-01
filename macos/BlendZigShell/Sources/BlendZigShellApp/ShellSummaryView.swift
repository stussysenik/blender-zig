import SwiftUI

struct ShellSummaryView: View {
    let model: ShellAppModel

    var body: some View {
        GroupBox("Document Summary") {
            VStack(alignment: .leading, spacing: 10) {
                if let request = model.currentRequest {
                    LabeledContent("Path") {
                        Text(request.url.path)
                            .textSelection(.enabled)
                    }
                    LabeledContent("Kind") {
                        Text(request.kind.displayName)
                    }
                } else {
                    Text("No document is open yet.")
                        .foregroundStyle(.secondary)
                }

                if let inspection = model.currentInspection {
                    if let formatVersion = inspection.formatVersion {
                        LabeledContent("Format Version") {
                            Text("\(formatVersion)")
                        }
                    }
                    if let replayID = inspection.replayID {
                        LabeledContent("Replay ID") {
                            Text(replayID)
                                .textSelection(.enabled)
                        }
                    }
                    LabeledContent("Title") {
                        Text(inspection.title ?? "(none)")
                            .textSelection(.enabled)
                    }
                    LabeledContent("Summary") {
                        Text(inspection.structureSummary)
                            .textSelection(.enabled)
                    }
                }

                if let result = model.currentResult {
                    LabeledContent("Helper") {
                        Text(result.helperBinaryPath)
                            .textSelection(.enabled)
                    }
                    LabeledContent("Command") {
                        Text(result.commandDisplay)
                            .textSelection(.enabled)
                    }
                    LabeledContent("Exit Status") {
                        Text("\(result.exitCode)")
                    }
                }

                if let errorMessage = model.errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .textSelection(.enabled)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
