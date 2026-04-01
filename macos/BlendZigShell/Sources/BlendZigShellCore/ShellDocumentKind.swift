import Foundation

public enum ShellDocumentKind: String, CaseIterable, Sendable {
    case recipe
    case scene
    case bundle

    public init?(url: URL) {
        switch url.pathExtension.lowercased() {
        case "bzrecipe":
            self = .recipe
        case "bzscene":
            self = .scene
        case "bzbundle":
            self = .bundle
        default:
            return nil
        }
    }

    public var displayName: String {
        switch self {
        case .recipe:
            ".bzrecipe study"
        case .scene:
            ".bzscene composition"
        case .bundle:
            ".bzbundle package"
        }
    }

    public var helperArgumentsPrefix: [String] {
        switch self {
        case .recipe:
            ["mesh-pipeline", "--recipe"]
        case .scene:
            ["mesh-scene", "--recipe"]
        case .bundle:
            ["geometry-bundle-open"]
        }
    }
}
