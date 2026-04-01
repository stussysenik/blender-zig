import BlendZigShellCore
import Foundation

struct ShellRuntime: Sendable {
    func open(_ request: ShellOpenRequest) throws -> ShellOpenResult {
        let helperBinaryURL = try resolveHelperBinaryURL()
        let process = Process()
        process.executableURL = helperBinaryURL
        process.arguments = request.helperArguments

        let standardOutputPipe = Pipe()
        let standardErrorPipe = Pipe()
        process.standardOutput = standardOutputPipe
        process.standardError = standardErrorPipe

        do {
            try process.run()
        } catch {
            throw ShellRuntimeError.failedToLaunch(helperBinaryURL.path)
        }
        process.waitUntilExit()

        let standardOutput = String(decoding: standardOutputPipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        let standardError = String(decoding: standardErrorPipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        return ShellOpenResult(
            request: request,
            helperBinaryPath: helperBinaryURL.path,
            invocation: [helperBinaryURL.path] + request.helperArguments,
            standardOutput: standardOutput,
            standardError: standardError,
            exitCode: process.terminationStatus
        )
    }

    private func resolveHelperBinaryURL() throws -> URL {
        if let overridePath = ProcessInfo.processInfo.environment["BLENDER_ZIG_BIN"], !overridePath.isEmpty {
            let url = URL(fileURLWithPath: overridePath).standardizedFileURL
            if FileManager.default.isExecutableFile(atPath: url.path) {
                return url
            }
        }

        if let executableURL = Bundle.main.executableURL {
            let bundledURL = executableURL
                .deletingLastPathComponent()
                .appendingPathComponent("blender-zig-direct")
            if FileManager.default.isExecutableFile(atPath: bundledURL.path) {
                return bundledURL
            }
        }

        throw ShellRuntimeError.missingHelperBinary
    }
}

enum ShellRuntimeError: LocalizedError {
    case missingHelperBinary
    case failedToLaunch(String)

    var errorDescription: String? {
        switch self {
        case .missingHelperBinary:
            "could not locate the bundled blender-zig-direct helper"
        case .failedToLaunch(let path):
            "failed to launch bundled helper at \(path)"
        }
    }
}
