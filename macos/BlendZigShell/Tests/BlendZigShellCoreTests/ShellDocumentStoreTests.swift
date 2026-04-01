import BlendZigShellCore
import Foundation
import Testing

@Test func inspectRecipeSurfacesMetadataAndStepCount() throws {
    let tempDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tempDirectory) }

    let recipeURL = tempDirectory.appendingPathComponent("study.bzrecipe")
    try """
    format-version=1
    id=phase-18/test-study
    title=Test Study
    seed=grid
    step=triangulate
    step=extrude:distance=0.5
    """.write(to: recipeURL, atomically: true, encoding: .utf8)

    let store = ShellDocumentStore()
    let inspection = try store.inspect(ShellOpenRequest(url: recipeURL))

    #expect(inspection.formatVersion == 1)
    #expect(inspection.replayID == "phase-18/test-study")
    #expect(inspection.title == "Test Study")
    #expect(inspection.structureSummary == "seed=grid steps=2")
    #expect(inspection.isEditable)
}

@Test func inspectSceneSurfacesPartCount() throws {
    let tempDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tempDirectory) }

    let sceneURL = tempDirectory.appendingPathComponent("scene.bzscene")
    try """
    format-version=1
    id=phase-18/test-scene
    title=Test Scene
    part=a.bzrecipe
    part=b.obj
    """.write(to: sceneURL, atomically: true, encoding: .utf8)

    let store = ShellDocumentStore()
    let inspection = try store.inspect(ShellOpenRequest(url: sceneURL))

    #expect(inspection.structureSummary == "parts=2")
    #expect(inspection.isEditable)
}

@Test func inspectBundleSurfacesComponentsButStaysInspectOnly() throws {
    let tempDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let bundleURL = tempDirectory.appendingPathComponent("sample.bzbundle", isDirectory: true)
    try FileManager.default.createDirectory(at: bundleURL, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tempDirectory) }

    let manifestURL = bundleURL.appendingPathComponent("manifest.bzmanifest")
    try """
    format-version=1
    title=Bundled Scene
    kind=geometry-bundle
    geometry-format=obj
    geometry-path=geometry.obj
    components=mesh,curves
    """.write(to: manifestURL, atomically: true, encoding: .utf8)

    let store = ShellDocumentStore()
    let inspection = try store.inspect(ShellOpenRequest(url: bundleURL))

    #expect(inspection.title == "Bundled Scene")
    #expect(inspection.structureSummary == "components=mesh,curves geometry-path=geometry.obj")
    #expect(!inspection.isEditable)
}

@Test func saveTitleUpdatesExistingRecipeMetadata() throws {
    let tempDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tempDirectory) }

    let recipeURL = tempDirectory.appendingPathComponent("study.bzrecipe")
    try """
    format-version=1
    id=phase-18/test-study
    title=Old Title
    seed=grid
    step=triangulate
    """.write(to: recipeURL, atomically: true, encoding: .utf8)

    let store = ShellDocumentStore()
    let inspection = try store.saveTitle("New Title", for: ShellOpenRequest(url: recipeURL))
    let text = try String(contentsOf: recipeURL, encoding: .utf8)
    let expectedText = """
    format-version=1
    id=phase-18/test-study
    title=New Title
    seed=grid
    step=triangulate
    """ + "\n"

    #expect(inspection.title == "New Title")
    #expect(text == expectedText)
}

@Test func saveTitleInsertsSceneMetadataWhenMissing() throws {
    let tempDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tempDirectory) }

    let sceneURL = tempDirectory.appendingPathComponent("scene.bzscene")
    try """
    format-version=1
    id=phase-18/test-scene
    part=a.bzrecipe
    """.write(to: sceneURL, atomically: true, encoding: .utf8)

    let store = ShellDocumentStore()
    let inspection = try store.saveTitle("Inserted Title", for: ShellOpenRequest(url: sceneURL))
    let text = try String(contentsOf: sceneURL, encoding: .utf8)
    let expectedText = """
    format-version=1
    id=phase-18/test-scene
    title=Inserted Title
    part=a.bzrecipe
    """ + "\n"

    #expect(inspection.title == "Inserted Title")
    #expect(text == expectedText)
}

@Test func saveTitleRejectsBundleMutation() throws {
    let tempDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let bundleURL = tempDirectory.appendingPathComponent("sample.bzbundle", isDirectory: true)
    try FileManager.default.createDirectory(at: bundleURL, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tempDirectory) }

    let manifestURL = bundleURL.appendingPathComponent("manifest.bzmanifest")
    try "format-version=1\n".write(to: manifestURL, atomically: true, encoding: .utf8)

    let store = ShellDocumentStore()
    #expect(throws: ShellDocumentStoreError.inspectOnlyDocument(.bundle)) {
        _ = try store.saveTitle("Nope", for: ShellOpenRequest(url: bundleURL))
    }
}

@Test func saveTitleRejectsRecipeOverwriteWhenFileChangedAfterOpen() throws {
    let tempDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tempDirectory) }

    let recipeURL = tempDirectory.appendingPathComponent("study.bzrecipe")
    try """
    format-version=1
    id=phase-18/test-study
    title=Original Title
    seed=grid
    step=triangulate
    """.write(to: recipeURL, atomically: true, encoding: .utf8)

    let store = ShellDocumentStore()
    let request = try ShellOpenRequest(url: recipeURL)
    let session = try store.inspectSession(request)

    let externalText = """
    format-version=1
    id=phase-18/test-study
    title=Externally Changed Title
    seed=grid
    step=triangulate
    """ + "\n"
    try externalText.write(to: recipeURL, atomically: true, encoding: .utf8)

    #expect(throws: ShellDocumentStoreError.documentChangedSinceOpen(.recipe)) {
        _ = try store.saveTitle("New Title", in: session)
    }

    let currentText = try String(contentsOf: recipeURL, encoding: .utf8)
    #expect(currentText == externalText)
}

@Test func inspectRecipeSurfacesEditableTrailingTransformState() throws {
    let tempDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tempDirectory) }

    let recipeURL = tempDirectory.appendingPathComponent("study.bzrecipe")
    try """
    format-version=1
    id=phase-19/test-transform-study
    title=Transform Study
    seed=sphere:radius=1.25,segments=12,rings=6,uvs=true
    write=/tmp/transform-study.obj
    step=triangulate
    step=scale:x=1.2,y=1.1,z=0.9
    step=rotate-z:degrees=22
    step=translate:x=2.5,y=-1.0,z=0.75
    """.write(to: recipeURL, atomically: true, encoding: .utf8)

    let inspection = try ShellDocumentStore().inspect(ShellOpenRequest(url: recipeURL))

    #expect(inspection.recipeTransformState == .init(
        values: .init(
            scaleX: 1.2,
            scaleY: 1.1,
            scaleZ: 0.9,
            rotateZDegrees: 22,
            translateX: 2.5,
            translateY: -1.0,
            translateZ: 0.75
        ),
        isEditable: true,
        message: nil
    ))
}

@Test func saveRecipeTransformInsertsTrailingTransformBlockWhenMissing() throws {
    let tempDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tempDirectory) }

    let recipeURL = tempDirectory.appendingPathComponent("study.bzrecipe")
    try """
    format-version=1
    id=phase-19/test-transform-study
    title=Transform Study
    seed=grid
    write=/tmp/transform-study.obj
    step=triangulate
    """.write(to: recipeURL, atomically: true, encoding: .utf8)

    let store = ShellDocumentStore()
    let session = try store.inspectSession(ShellOpenRequest(url: recipeURL))
    let updatedSession = try store.saveRecipeTransform(.init(
        scaleX: 1.2,
        scaleY: 1.1,
        scaleZ: 0.9,
        rotateZDegrees: 22,
        translateX: 2.5,
        translateY: -1.0,
        translateZ: 0.75
    ), in: session)

    let text = try String(contentsOf: recipeURL, encoding: .utf8)
    let expectedText = """
    format-version=1
    id=phase-19/test-transform-study
    title=Transform Study
    seed=grid
    write=/tmp/transform-study.obj
    step=triangulate
    step=scale:x=1.2,y=1.1,z=0.9
    step=rotate-z:degrees=22.0
    step=translate:x=2.5,y=-1.0,z=0.75
    """ + "\n"

    #expect(updatedSession.inspection.recipeTransformState?.isEditable == true)
    #expect(text == expectedText)
}

@Test func saveRecipeTransformRewritesTrailingTransformBlockInNormalizedOrder() throws {
    let tempDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tempDirectory) }

    let recipeURL = tempDirectory.appendingPathComponent("study.bzrecipe")
    try """
    format-version=1
    id=phase-19/test-transform-study
    title=Transform Study
    seed=grid
    write=/tmp/transform-study.obj
    step=delete-face:index=1
    step=translate:x=1.0,y=0.0,z=0.0
    """.write(to: recipeURL, atomically: true, encoding: .utf8)

    let store = ShellDocumentStore()
    let session = try store.inspectSession(ShellOpenRequest(url: recipeURL))
    _ = try store.saveRecipeTransform(.init(
        scaleX: 1.5,
        scaleY: 1.0,
        scaleZ: 1.0,
        rotateZDegrees: 15,
        translateX: 0.5,
        translateY: 0.25,
        translateZ: 0.0
    ), in: session)

    let text = try String(contentsOf: recipeURL, encoding: .utf8)
    let expectedText = """
    format-version=1
    id=phase-19/test-transform-study
    title=Transform Study
    seed=grid
    write=/tmp/transform-study.obj
    step=delete-face:index=1
    step=scale:x=1.5,y=1.0,z=1.0
    step=rotate-z:degrees=15.0
    step=translate:x=0.5,y=0.25,z=0.0
    """ + "\n"

    #expect(text == expectedText)
}

@Test func saveRecipeTransformRejectsInterleavedTransformHistory() throws {
    let tempDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tempDirectory) }

    let recipeURL = tempDirectory.appendingPathComponent("study.bzrecipe")
    try """
    format-version=1
    id=phase-19/test-transform-study
    title=Transform Study
    seed=grid
    write=/tmp/transform-study.obj
    step=translate:x=1.0,y=0.0,z=0.0
    step=delete-face:index=1
    """.write(to: recipeURL, atomically: true, encoding: .utf8)

    let store = ShellDocumentStore()
    let request = try ShellOpenRequest(url: recipeURL)
    let inspection = try store.inspect(request)
    let session = try store.inspectSession(request)

    #expect(inspection.recipeTransformState == .init(
        values: .identity,
        isEditable: false,
        message: "transform editing is unavailable because recipe transform steps are not isolated in a trailing block"
    ))
    #expect(throws: ShellDocumentStoreError.unsupportedRecipeTransformEditing) {
        _ = try store.saveRecipeTransform(.init(
            scaleX: 1.1,
            scaleY: 1.1,
            scaleZ: 1.1,
            rotateZDegrees: 0,
            translateX: 0,
            translateY: 0,
            translateZ: 0
        ), in: session)
    }
}
