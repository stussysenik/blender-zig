import BlendZigShellCore
import Foundation
import Testing

@Test func previewArtifactExtractsAbsoluteObjPathFromRecipeReplay() throws {
    let request = try ShellOpenRequest(url: URL(fileURLWithPath: "/tmp/study.bzrecipe"))
    let result = ShellOpenResult(
        request: request,
        helperBinaryPath: "/tmp/blender-zig-direct",
        invocation: ["/tmp/blender-zig-direct", "mesh-pipeline", "--recipe", "/tmp/study.bzrecipe"],
        standardOutput: """
        replay kind=recipe format-version=1 id=phase-19/test title=Test
        command=mesh-pipeline vertices=8 edges=12 faces=6
        wrote /tmp/preview.obj
        """,
        standardError: "",
        exitCode: 0
    )

    let artifact = ShellPreviewArtifact(result: result)

    #expect(artifact?.geometryURL == URL(fileURLWithPath: "/tmp/preview.obj"))
}

@Test func previewArtifactResolvesRelativeObjPathAgainstOpenedSceneDirectory() throws {
    let request = try ShellOpenRequest(url: URL(fileURLWithPath: "/tmp/phase-19/workbench.bzscene"))
    let result = ShellOpenResult(
        request: request,
        helperBinaryPath: "/tmp/blender-zig-direct",
        invocation: ["/tmp/blender-zig-direct", "mesh-scene", "--recipe", "/tmp/phase-19/workbench.bzscene"],
        standardOutput: """
        replay kind=scene format-version=1 id=phase-19/workbench title=Workbench
        wrote preview/workbench.obj
        """,
        standardError: "",
        exitCode: 0
    )

    let artifact = ShellPreviewArtifact(result: result)

    #expect(artifact?.geometryURL == URL(fileURLWithPath: "/tmp/phase-19/preview/workbench.obj"))
}

@Test func previewArtifactStaysUnavailableForBundles() throws {
    let request = try ShellOpenRequest(url: URL(fileURLWithPath: "/tmp/preview.bzbundle"))
    let result = ShellOpenResult(
        request: request,
        helperBinaryPath: "/tmp/blender-zig-direct",
        invocation: ["/tmp/blender-zig-direct", "geometry-bundle-open", "/tmp/preview.bzbundle"],
        standardOutput: """
        replay kind=bundle format-version=1 title=Preview Bundle
        bundle path=/tmp/preview.bzbundle components=mesh geometry-format=obj manifest=manifest.bzmanifest
        """,
        standardError: "",
        exitCode: 0
    )

    #expect(ShellPreviewArtifact(result: result) == nil)
}
