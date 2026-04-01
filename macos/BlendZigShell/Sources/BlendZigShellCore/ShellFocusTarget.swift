import Foundation

public struct ShellFocusProperty: Equatable, Sendable {
    public let label: String
    public let value: String

    public init(label: String, value: String) {
        self.label = label
        self.value = value
    }
}

public struct ShellFocusTarget: Equatable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let kind: String
    public let summary: String
    public let properties: [ShellFocusProperty]

    public init(
        id: String,
        name: String,
        kind: String,
        summary: String,
        properties: [ShellFocusProperty]
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.summary = summary
        self.properties = properties
    }
}
