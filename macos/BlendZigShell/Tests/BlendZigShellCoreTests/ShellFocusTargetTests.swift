import BlendZigShellCore
import Foundation
import Testing

@Test func recipeInspectionBuildsSingleFocusedObjectFromSeed() throws {
    let tempDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tempDirectory) }

    let recipeURL = tempDirectory.appendingPathComponent("study.bzrecipe")
    try """
    format-version=1
    id=phase-19/test-study
    title=Test Study
    seed=sphere:radius=1.25,segments=12,rings=6,uvs=true
    write=../zig-out/test-study.obj
    step=translate:x=1.0,y=0.0,z=0.0
    step=scale:x=1.1,y=1.1,z=1.1
    """.write(to: recipeURL, atomically: true, encoding: .utf8)

    let inspection = try ShellDocumentStore().inspect(ShellOpenRequest(url: recipeURL))

    #expect(inspection.focusTargets.count == 1)
    #expect(inspection.defaultFocusTargetID == "study-root")

    let target = try #require(inspection.focusTargets.first)
    #expect(target.id == "study-root")
    #expect(target.name == "Test Study")
    #expect(target.kind == "sphere")
    #expect(target.summary == "primitive study")
    #expect(target.properties == [
        .init(label: "Seed", value: "sphere"),
        .init(label: "Steps", value: "2"),
        .init(label: "Write", value: "../zig-out/test-study.obj"),
    ])
}

@Test func sceneInspectionBuildsFocusableTargetsPerPart() throws {
    let tempDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tempDirectory) }

    let sceneURL = tempDirectory.appendingPathComponent("scene.bzscene")
    try """
    format-version=1
    id=phase-19/test-scene
    title=Test Scene
    part=plate.obj|translate:x=0.0,y=0.0,z=-0.02
    part=study-a.bzrecipe
    part=study-b.bzrecipe|translate:x=0.8,y=-0.1,z=0.0|rotate-z:degrees=6
    """.write(to: sceneURL, atomically: true, encoding: .utf8)

    let inspection = try ShellDocumentStore().inspect(ShellOpenRequest(url: sceneURL))

    #expect(inspection.focusTargets.count == 3)
    #expect(inspection.defaultFocusTargetID == "part-0")

    let first = inspection.focusTargets[0]
    #expect(first.name == "plate")
    #expect(first.kind == "obj")
    #expect(first.summary == "scene part")
    #expect(first.properties == [
        .init(label: "Source", value: "plate.obj"),
        .init(label: "Placement", value: "translate:x=0.0,y=0.0,z=-0.02"),
    ])

    let third = inspection.focusTargets[2]
    #expect(third.name == "study-b")
    #expect(third.kind == "bzrecipe")
    #expect(third.properties == [
        .init(label: "Source", value: "study-b.bzrecipe"),
        .init(label: "Placement", value: "translate:x=0.8,y=-0.1,z=0.0; rotate-z:degrees=6"),
    ])
}

@Test func creatingPrimitiveStudyWritesRecipeAndReturnsInspectableSession() throws {
    let tempDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tempDirectory) }

    let studyURL = tempDirectory.appendingPathComponent("starter-sphere.bzrecipe")
    let session = try ShellDocumentStore().createPrimitiveStudy(
        template: .sphere,
        at: studyURL,
        title: "Starter Sphere"
    )

    let text = try String(contentsOf: studyURL, encoding: .utf8)
    #expect(text.contains("id=starter-sphere"))
    #expect(text.contains("title=Starter Sphere"))
    #expect(text.contains("seed=sphere:radius=1.25,segments=12,rings=6,uvs=true"))
    #expect(text.contains("write=\(tempDirectory.appendingPathComponent("starter-sphere.obj").path)"))
    #expect(session.inspection.request.url == studyURL.standardizedFileURL)
    #expect(session.inspection.focusTargets.count == 1)
    #expect(session.inspection.focusTargets[0].kind == "sphere")
}
