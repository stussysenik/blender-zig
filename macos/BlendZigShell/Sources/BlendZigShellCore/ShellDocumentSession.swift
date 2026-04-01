import Foundation

public struct ShellDocumentSession: Sendable {
    public let inspection: ShellInspectedDocument
    let originalText: String

    init(inspection: ShellInspectedDocument, originalText: String) {
        self.inspection = inspection
        self.originalText = originalText
    }
}
