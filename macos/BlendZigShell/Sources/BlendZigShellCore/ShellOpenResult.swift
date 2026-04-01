import Foundation

public struct ShellOpenResult: Sendable {
    public let request: ShellOpenRequest
    public let helperBinaryPath: String
    public let invocation: [String]
    public let standardOutput: String
    public let standardError: String
    public let exitCode: Int32

    public init(
        request: ShellOpenRequest,
        helperBinaryPath: String,
        invocation: [String],
        standardOutput: String,
        standardError: String,
        exitCode: Int32
    ) {
        self.request = request
        self.helperBinaryPath = helperBinaryPath
        self.invocation = invocation
        self.standardOutput = standardOutput
        self.standardError = standardError
        self.exitCode = exitCode
    }

    public var succeeded: Bool {
        exitCode == 0
    }

    public var commandDisplay: String {
        invocation.joined(separator: " ")
    }
}
