import BlendZigShellCore
import Foundation
import SceneKit
import SwiftUI

let shellLaunchMode: ShellLaunchMode = {
    do {
        return try ShellLaunchMode.parse(arguments: CommandLine.arguments)
    } catch {
        let message = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
        FileHandle.standardError.write(Data("error: \(message)\n".utf8))
        exit(1)
    }
}()

switch shellLaunchMode {
case .interactive:
    BlendZigShellApp.main()
case .smokeOpen(let request):
    do {
        let result = try ShellRuntime().open(request)
        if !result.standardOutput.isEmpty {
            FileHandle.standardOutput.write(Data(result.standardOutput.utf8))
        }
        if !result.standardError.isEmpty {
            FileHandle.standardError.write(Data(result.standardError.utf8))
        }
        exit(result.exitCode)
    } catch {
        let message = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
        FileHandle.standardError.write(Data("error: \(message)\n".utf8))
        exit(1)
    }
case .smokeInspect(let request):
    do {
        let inspection = try ShellDocumentStore().inspect(request)
        FileHandle.standardOutput.write(Data(renderInspection(inspection).utf8))
        exit(0)
    } catch {
        let message = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
        FileHandle.standardError.write(Data("error: \(message)\n".utf8))
        exit(1)
    }
case .smokePreview(let request):
    do {
        let result = try ShellRuntime().open(request)
        let preview = try ShellViewportPreview.load(from: result)
        FileHandle.standardOutput.write(Data(renderPreview(preview).utf8))
        exit(0)
    } catch {
        let message = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
        FileHandle.standardError.write(Data("error: \(message)\n".utf8))
        exit(1)
    }
case .smokeCreatePrimitive(let template, let path):
    do {
        let store = ShellDocumentStore()
        let session = try store.createPrimitiveStudy(template: template, at: path)
        let result = try ShellRuntime().open(session.inspection.request)
        FileHandle.standardOutput.write(Data(renderInspection(session.inspection).utf8))
        if !result.standardOutput.isEmpty {
            FileHandle.standardOutput.write(Data(result.standardOutput.utf8))
        }
        if !result.standardError.isEmpty {
            FileHandle.standardError.write(Data(result.standardError.utf8))
        }
        exit(result.exitCode)
    } catch {
        let message = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
        FileHandle.standardError.write(Data("error: \(message)\n".utf8))
        exit(1)
    }
case .smokeSaveRecipeSubdivide(let request, let isApplied):
    do {
        let store = ShellDocumentStore()
        let session = try store.inspectSession(request)
        let updatedSession = try store.saveRecipeSubdivide(isApplied, in: session)
        FileHandle.standardOutput.write(Data(renderInspection(updatedSession.inspection).utf8))

        let result = try ShellRuntime().open(request)
        if !result.standardOutput.isEmpty {
            FileHandle.standardOutput.write(Data(result.standardOutput.utf8))
        }
        if !result.standardError.isEmpty {
            FileHandle.standardError.write(Data(result.standardError.utf8))
        }
        exit(result.exitCode)
    } catch {
        let message = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
        FileHandle.standardError.write(Data("error: \(message)\n".utf8))
        exit(1)
    }
case .smokeSaveRecipeTransform(let request, let values):
    do {
        let store = ShellDocumentStore()
        let session = try store.inspectSession(request)
        let updatedSession = try store.saveRecipeTransform(values, in: session)
        FileHandle.standardOutput.write(Data(renderInspection(updatedSession.inspection).utf8))

        let result = try ShellRuntime().open(request)
        if !result.standardOutput.isEmpty {
            FileHandle.standardOutput.write(Data(result.standardOutput.utf8))
        }
        if !result.standardError.isEmpty {
            FileHandle.standardError.write(Data(result.standardError.utf8))
        }
        exit(result.exitCode)
    } catch {
        let message = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
        FileHandle.standardError.write(Data("error: \(message)\n".utf8))
        exit(1)
    }
case .smokeSaveTitle(let request, let title):
    do {
        let store = ShellDocumentStore()
        let session = try store.inspectSession(request)
        let updatedSession = try store.saveTitle(title, in: session)
        FileHandle.standardOutput.write(Data(renderInspection(updatedSession.inspection).utf8))

        let result = try ShellRuntime().open(request)
        if !result.standardOutput.isEmpty {
            FileHandle.standardOutput.write(Data(result.standardOutput.utf8))
        }
        if !result.standardError.isEmpty {
            FileHandle.standardError.write(Data(result.standardError.utf8))
        }
        exit(result.exitCode)
    } catch {
        let message = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
        FileHandle.standardError.write(Data("error: \(message)\n".utf8))
        exit(1)
    }
case .smokeSaveTitleConflict(let request, let externalTitle, let title):
    do {
        let store = ShellDocumentStore()
        let session = try store.inspectSession(request)
        _ = try store.saveTitle(externalTitle, for: request)
        _ = try store.saveTitle(title, in: session)
        FileHandle.standardError.write(Data("error: expected save conflict\n".utf8))
        exit(1)
    } catch {
        let message = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
        FileHandle.standardError.write(Data("error: \(message)\n".utf8))
        exit(1)
    }
}

private func renderInspection(_ inspection: ShellInspectedDocument) -> String {
    var fields = [
        "inspect kind=\(inspection.request.kind.rawValue)",
        "path=\(inspection.request.url.path)",
        "editable=\(inspection.isEditable ? "true" : "false")",
    ]
    if let formatVersion = inspection.formatVersion {
        fields.append("format-version=\(formatVersion)")
    }
    if let replayID = inspection.replayID {
        fields.append("id=\(replayID)")
    }
    if let title = inspection.title {
        fields.append("title=\(title)")
    }
    fields.append("summary=\(inspection.structureSummary)")
    fields.append("focus-targets=\(inspection.focusTargets.count)")
    if let focusedID = inspection.defaultFocusTargetID {
        fields.append("focused=\(focusedID)")
    }
    if let target = inspection.focusTargets.first(where: { $0.id == inspection.defaultFocusTargetID }) ?? inspection.focusTargets.first {
        fields.append("focus-kind=\(target.kind)")
        fields.append("focus-name=\(target.name)")
    }
    if let transformState = inspection.recipeTransformState {
        fields.append("transform-editable=\(transformState.isEditable ? "true" : "false")")
        fields.append("transform-scale=\(renderTransformVector(transformState.values.scaleX, transformState.values.scaleY, transformState.values.scaleZ))")
        fields.append("transform-rotate-z=\(transformState.values.rotateZDegrees)")
        fields.append("transform-translate=\(renderTransformVector(transformState.values.translateX, transformState.values.translateY, transformState.values.translateZ))")
    }
    if let subdivideState = inspection.recipeSubdivideState {
        fields.append("subdivide-editable=\(subdivideState.isEditable ? "true" : "false")")
        fields.append("subdivide-applied=\(subdivideState.isApplied ? "true" : "false")")
    }
    return fields.joined(separator: " ") + "\n"
}

private func renderPreview(_ preview: ShellViewportPreview) -> String {
    [
        "preview kind=\(preview.artifact.request.kind.rawValue)",
        "geometry=\(preview.artifact.geometryURL.path)",
        "camera-position=\(renderVector(preview.cameraPosition))",
        "camera-target=\(renderVector(preview.cameraTarget))",
    ].joined(separator: " ") + "\n"
}

private func renderVector(_ vector: SCNVector3) -> String {
    "(\(vector.x),\(vector.y),\(vector.z))"
}

private func renderTransformVector(_ x: Double, _ y: Double, _ z: Double) -> String {
    "(\(x),\(y),\(z))"
}
