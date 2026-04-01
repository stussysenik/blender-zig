import Foundation

public struct ShellPreviewArtifact: Equatable, Sendable {
    public let request: ShellOpenRequest
    public let geometryURL: URL

    public init?(result: ShellOpenResult) {
        guard result.succeeded else { return nil }
        guard result.request.kind != .bundle else { return nil }
        guard let geometryURL = Self.resolveGeometryURL(from: result.standardOutput, request: result.request) else {
            return nil
        }

        self.request = result.request
        self.geometryURL = geometryURL
    }

    private static func resolveGeometryURL(from standardOutput: String, request: ShellOpenRequest) -> URL? {
        let outputPath = standardOutput
            .split(separator: "\n")
            .compactMap { line -> String? in
                guard line.hasPrefix("wrote ") else { return nil }
                return String(line.dropFirst("wrote ".count))
            }
            .last

        guard let outputPath, outputPath.lowercased().hasSuffix(".obj") else {
            return nil
        }

        if outputPath.hasPrefix("/") {
            return URL(fileURLWithPath: outputPath).standardizedFileURL
        }

        return URL(
            fileURLWithPath: outputPath,
            relativeTo: request.url.deletingLastPathComponent()
        ).standardizedFileURL
    }
}
