import BlendZigShellCore
import Foundation
import Testing

@Test func launchModeDefaultsToInteractiveWithoutStartupRequest() throws {
    let mode = try ShellLaunchMode.parse(arguments: ["BlendZigShell"])
    #expect(mode == .interactive(startupRequest: nil))
}

@Test func launchModeBuildsInteractiveStartupRequestFromPathArgument() throws {
    let mode = try ShellLaunchMode.parse(arguments: ["BlendZigShell", "/tmp/example.bzscene"])
    #expect(mode == .interactive(startupRequest: try ShellOpenRequest(url: .init(fileURLWithPath: "/tmp/example.bzscene"))))
}

@Test func launchModeBuildsSmokeRequest() throws {
    let mode = try ShellLaunchMode.parse(arguments: ["BlendZigShell", "--smoke-open", "/tmp/example.bzbundle"])
    #expect(mode == .smokeOpen(try ShellOpenRequest(url: .init(fileURLWithPath: "/tmp/example.bzbundle"))))
}

@Test func launchModeBuildsSmokeInspectRequest() throws {
    let mode = try ShellLaunchMode.parse(arguments: ["BlendZigShell", "--smoke-inspect", "/tmp/example.bzrecipe"])
    #expect(mode == .smokeInspect(try ShellOpenRequest(url: .init(fileURLWithPath: "/tmp/example.bzrecipe"))))
}

@Test func launchModeBuildsSmokePreviewRequest() throws {
    let mode = try ShellLaunchMode.parse(arguments: ["BlendZigShell", "--smoke-preview", "/tmp/example.bzrecipe"])
    #expect(mode == .smokePreview(try ShellOpenRequest(url: .init(fileURLWithPath: "/tmp/example.bzrecipe"))))
}

@Test func launchModeBuildsSmokeCreatePrimitiveRequest() throws {
    let mode = try ShellLaunchMode.parse(arguments: ["BlendZigShell", "--smoke-create-primitive", "sphere", "/tmp/starter-sphere.bzrecipe"])
    #expect(mode == .smokeCreatePrimitive(
        template: .sphere,
        path: URL(fileURLWithPath: "/tmp/starter-sphere.bzrecipe")
    ))
}

@Test func launchModeBuildsSmokeSaveRecipeTransformRequest() throws {
    let mode = try ShellLaunchMode.parse(arguments: [
        "BlendZigShell",
        "--smoke-save-recipe-transform",
        "/tmp/starter-sphere.bzrecipe",
        "1.2",
        "1.1",
        "0.9",
        "22",
        "2.5",
        "-1.0",
        "0.75",
    ])
    #expect(mode == .smokeSaveRecipeTransform(
        request: try ShellOpenRequest(url: .init(fileURLWithPath: "/tmp/starter-sphere.bzrecipe")),
        values: .init(
            scaleX: 1.2,
            scaleY: 1.1,
            scaleZ: 0.9,
            rotateZDegrees: 22.0,
            translateX: 2.5,
            translateY: -1.0,
            translateZ: 0.75
        )
    ))
}

@Test func launchModeBuildsSmokeSaveTitleRequest() throws {
    let mode = try ShellLaunchMode.parse(arguments: ["BlendZigShell", "--smoke-save-title", "/tmp/example.bzscene", "Updated Title"])
    #expect(mode == .smokeSaveTitle(
        request: try ShellOpenRequest(url: .init(fileURLWithPath: "/tmp/example.bzscene")),
        title: "Updated Title"
    ))
}

@Test func launchModeBuildsSmokeSaveTitleConflictRequest() throws {
    let mode = try ShellLaunchMode.parse(arguments: [
        "BlendZigShell",
        "--smoke-save-title-conflict",
        "/tmp/example.bzrecipe",
        "External Title",
        "Requested Title",
    ])
    #expect(mode == .smokeSaveTitleConflict(
        request: try ShellOpenRequest(url: .init(fileURLWithPath: "/tmp/example.bzrecipe")),
        externalTitle: "External Title",
        title: "Requested Title"
    ))
}

@Test func launchModeIgnoresMacLaunchServicesArguments() throws {
    let mode = try ShellLaunchMode.parse(arguments: ["BlendZigShell", "-psn_0_12345"])
    #expect(mode == .interactive(startupRequest: nil))
}

@Test func launchModeRejectsMissingSmokePath() {
    #expect(throws: ShellLaunchModeError.missingSmokePath) {
        _ = try ShellLaunchMode.parse(arguments: ["BlendZigShell", "--smoke-open"])
    }
}

@Test func launchModeRejectsMissingSmokePrimitiveArguments() {
    #expect(throws: ShellLaunchModeError.missingSmokePrimitiveArguments) {
        _ = try ShellLaunchMode.parse(arguments: ["BlendZigShell", "--smoke-create-primitive", "sphere"])
    }
}

@Test func launchModeRejectsMissingSmokeRecipeTransformArguments() {
    #expect(throws: ShellLaunchModeError.missingSmokeRecipeTransformArguments) {
        _ = try ShellLaunchMode.parse(arguments: ["BlendZigShell", "--smoke-save-recipe-transform", "/tmp/starter-sphere.bzrecipe", "1.2"])
    }
}

@Test func launchModeRejectsMissingSmokeTitle() {
    #expect(throws: ShellLaunchModeError.missingSmokeTitle) {
        _ = try ShellLaunchMode.parse(arguments: ["BlendZigShell", "--smoke-save-title", "/tmp/example.bzscene"])
    }
}

@Test func launchModeRejectsMissingConflictSmokeTitles() {
    #expect(throws: ShellLaunchModeError.missingConflictSmokeTitles) {
        _ = try ShellLaunchMode.parse(arguments: ["BlendZigShell", "--smoke-save-title-conflict", "/tmp/example.bzrecipe", "External Title"])
    }
}
