import Foundation

public enum ShellLaunchMode: Equatable, Sendable {
    case interactive(startupRequest: ShellOpenRequest?)
    case smokeOpen(ShellOpenRequest)
    case smokeInspect(ShellOpenRequest)
    case smokePreview(ShellOpenRequest)
    case smokeCreatePrimitive(template: ShellPrimitiveTemplate, path: URL)
    case smokeSaveRecipeSubdivide(request: ShellOpenRequest, isApplied: Bool)
    case smokeSaveRecipeTransform(request: ShellOpenRequest, values: ShellRecipeTransformValues)
    case smokeSaveTitle(request: ShellOpenRequest, title: String)
    case smokeSaveTitleConflict(request: ShellOpenRequest, externalTitle: String, title: String)

    public static func parse(arguments: [String]) throws -> Self {
        let filteredArguments = arguments
            .dropFirst()
            .filter { !$0.hasPrefix("-psn_") }

        if filteredArguments.isEmpty {
            return .interactive(startupRequest: nil)
        }

        if filteredArguments.first == "--smoke-open" {
            guard filteredArguments.count == 2 else {
                throw ShellLaunchModeError.missingSmokePath
            }
            return .smokeOpen(try ShellOpenRequest(url: URL(fileURLWithPath: filteredArguments[1])))
        }

        if filteredArguments.first == "--smoke-inspect" {
            guard filteredArguments.count == 2 else {
                throw ShellLaunchModeError.missingSmokePath
            }
            return .smokeInspect(try ShellOpenRequest(url: URL(fileURLWithPath: filteredArguments[1])))
        }

        if filteredArguments.first == "--smoke-preview" {
            guard filteredArguments.count == 2 else {
                throw ShellLaunchModeError.missingSmokePath
            }
            return .smokePreview(try ShellOpenRequest(url: URL(fileURLWithPath: filteredArguments[1])))
        }

        if filteredArguments.first == "--smoke-create-primitive" {
            guard filteredArguments.count == 3 else {
                throw ShellLaunchModeError.missingSmokePrimitiveArguments
            }
            return .smokeCreatePrimitive(
                template: try ShellPrimitiveTemplate(name: filteredArguments[1]),
                path: URL(fileURLWithPath: filteredArguments[2])
            )
        }

        if filteredArguments.first == "--smoke-save-recipe-subdivide" {
            guard filteredArguments.count == 3 else {
                throw ShellLaunchModeError.missingSmokeRecipeSubdivideArguments
            }
            return .smokeSaveRecipeSubdivide(
                request: try ShellOpenRequest(url: URL(fileURLWithPath: filteredArguments[1])),
                isApplied: try parseBooleanToggle(filteredArguments[2], field: "recipe-subdivide")
            )
        }

        if filteredArguments.first == "--smoke-save-recipe-transform" {
            guard filteredArguments.count == 9 else {
                throw ShellLaunchModeError.missingSmokeRecipeTransformArguments
            }
            return .smokeSaveRecipeTransform(
                request: try ShellOpenRequest(url: URL(fileURLWithPath: filteredArguments[1])),
                values: try .init(
                    scaleX: parseDouble(filteredArguments[2], field: "scale-x"),
                    scaleY: parseDouble(filteredArguments[3], field: "scale-y"),
                    scaleZ: parseDouble(filteredArguments[4], field: "scale-z"),
                    rotateZDegrees: parseDouble(filteredArguments[5], field: "rotate-z"),
                    translateX: parseDouble(filteredArguments[6], field: "translate-x"),
                    translateY: parseDouble(filteredArguments[7], field: "translate-y"),
                    translateZ: parseDouble(filteredArguments[8], field: "translate-z")
                )
            )
        }

        if filteredArguments.first == "--smoke-save-title" {
            guard filteredArguments.count == 3 else {
                throw ShellLaunchModeError.missingSmokeTitle
            }
            return .smokeSaveTitle(
                request: try ShellOpenRequest(url: URL(fileURLWithPath: filteredArguments[1])),
                title: filteredArguments[2]
            )
        }

        if filteredArguments.first == "--smoke-save-title-conflict" {
            guard filteredArguments.count == 4 else {
                throw ShellLaunchModeError.missingConflictSmokeTitles
            }
            return .smokeSaveTitleConflict(
                request: try ShellOpenRequest(url: URL(fileURLWithPath: filteredArguments[1])),
                externalTitle: filteredArguments[2],
                title: filteredArguments[3]
            )
        }

        guard filteredArguments.count == 1 else {
            throw ShellLaunchModeError.unexpectedArguments(filteredArguments)
        }

        return .interactive(startupRequest: try ShellOpenRequest(url: URL(fileURLWithPath: filteredArguments[0])))
    }
}

public enum ShellLaunchModeError: LocalizedError, Equatable {
    case missingSmokePath
    case missingSmokePrimitiveArguments
    case missingSmokeRecipeSubdivideArguments
    case missingSmokeRecipeTransformArguments
    case missingSmokeTitle
    case missingConflictSmokeTitles
    case invalidSmokeBooleanToggle(field: String, value: String)
    case invalidSmokeRecipeTransformValue(field: String, value: String)
    case unexpectedArguments([String])

    public var errorDescription: String? {
        switch self {
        case .missingSmokePath:
            "missing path after smoke command"
        case .missingSmokePrimitiveArguments:
            "missing primitive template or path after --smoke-create-primitive"
        case .missingSmokeRecipeSubdivideArguments:
            "missing path or mode after --smoke-save-recipe-subdivide"
        case .missingSmokeRecipeTransformArguments:
            "missing path or transform values after --smoke-save-recipe-transform"
        case .missingSmokeTitle:
            "missing title after --smoke-save-title"
        case .missingConflictSmokeTitles:
            "missing external or requested title after --smoke-save-title-conflict"
        case .invalidSmokeBooleanToggle(let field, let value):
            "invalid toggle value for \(field): \(value)"
        case .invalidSmokeRecipeTransformValue(let field, let value):
            "invalid numeric value for \(field): \(value)"
        case .unexpectedArguments(let arguments):
            "unexpected shell arguments: \(arguments.joined(separator: " "))"
        }
    }
}

private func parseDouble(_ rawValue: String, field: String) throws -> Double {
    guard let value = Double(rawValue) else {
        throw ShellLaunchModeError.invalidSmokeRecipeTransformValue(field: field, value: rawValue)
    }
    return value
}

private func parseBooleanToggle(_ rawValue: String, field: String) throws -> Bool {
    switch rawValue.lowercased() {
    case "on", "true", "apply":
        true
    case "off", "false", "remove":
        false
    default:
        throw ShellLaunchModeError.invalidSmokeBooleanToggle(field: field, value: rawValue)
    }
}
