import Foundation

public struct ShellOpenRequest: Equatable, Sendable {
    public let url: URL
    public let kind: ShellDocumentKind

    public init(url: URL) throws {
        let normalized = url.standardizedFileURL
        guard let kind = ShellDocumentKind(url: normalized) else {
            throw ShellOpenRequestError.unsupportedFileType(normalized.pathExtension)
        }

        self.url = normalized
        self.kind = kind
    }

    public var helperArguments: [String] {
        kind.helperArgumentsPrefix + [url.path]
    }
}

public enum ShellOpenRequestError: LocalizedError, Equatable {
    case unsupportedFileType(String)

    public var errorDescription: String? {
        switch self {
        case .unsupportedFileType(let pathExtension):
            if pathExtension.isEmpty {
                "unsupported file type: expected .bzrecipe, .bzscene, or .bzbundle"
            } else {
                "unsupported file type: .\(pathExtension)"
            }
        }
    }
}
