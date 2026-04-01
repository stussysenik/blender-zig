import BlendZigShellCore
import Foundation
import Testing

@Test func openRequestBuildsRecipeArguments() throws {
    let request = try ShellOpenRequest(url: URL(fileURLWithPath: "/tmp/example.bzrecipe"))
    #expect(request.helperArguments == ["mesh-pipeline", "--recipe", "/tmp/example.bzrecipe"])
}

@Test func openRequestBuildsSceneArguments() throws {
    let request = try ShellOpenRequest(url: URL(fileURLWithPath: "/tmp/example.bzscene"))
    #expect(request.helperArguments == ["mesh-scene", "--recipe", "/tmp/example.bzscene"])
}

@Test func openRequestBuildsBundleArguments() throws {
    let request = try ShellOpenRequest(url: URL(fileURLWithPath: "/tmp/example.bzbundle"))
    #expect(request.helperArguments == ["geometry-bundle-open", "/tmp/example.bzbundle"])
}

@Test func openRequestRejectsUnsupportedTypes() {
    #expect(throws: ShellOpenRequestError.unsupportedFileType("obj")) {
        _ = try ShellOpenRequest(url: URL(fileURLWithPath: "/tmp/example.obj"))
    }
}
