import BlendZigShellCore
import Foundation
import Testing

@Test func primitiveTemplateBuildsCuboidStudyText() throws {
    let rootDirectory = URL(fileURLWithPath: "/tmp/blender-zig-tests", isDirectory: true)
    let studyURL = rootDirectory.appendingPathComponent("starter-cuboid.bzrecipe")

    let text = ShellPrimitiveTemplate.cuboid.renderRecipeText(
        title: "Starter Cuboid",
        replayID: "phase-19/starter-cuboid",
        studyURL: studyURL
    )

    #expect(text.contains("format-version=1\n"))
    #expect(text.contains("id=phase-19/starter-cuboid\n"))
    #expect(text.contains("title=Starter Cuboid\n"))
    #expect(text.contains("seed=cuboid:size-x=2.0,size-y=2.0,size-z=2.0,verts-x=2,verts-y=2,verts-z=2,uvs=true\n"))
    #expect(text.contains("write=/tmp/blender-zig-tests/starter-cuboid.obj\n"))
}

@Test func primitiveTemplateCreatesExpectedFileStemAndDisplayName() {
    #expect(ShellPrimitiveTemplate.cuboid.fileStem == "cuboid-study")
    #expect(ShellPrimitiveTemplate.cylinder.fileStem == "cylinder-study")
    #expect(ShellPrimitiveTemplate.sphere.fileStem == "sphere-study")
    #expect(ShellPrimitiveTemplate.sphere.displayName == "Sphere")
}
