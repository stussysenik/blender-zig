import BlendZigShellCore
import Foundation
import SceneKit

struct ShellViewportPreview {
    let artifact: ShellPreviewArtifact
    let scene: SCNScene
    let cameraNode: SCNNode
    let targetNode: SCNNode
    let cameraPosition: SCNVector3
    let cameraTarget: SCNVector3

    static func load(from result: ShellOpenResult) throws -> Self {
        guard let artifact = ShellPreviewArtifact(result: result) else {
            throw ShellViewportPreviewError.previewUnavailable(result.request.kind)
        }
        return try load(from: artifact)
    }

    static func load(from artifact: ShellPreviewArtifact) throws -> Self {
        do {
            let scene = try SCNScene(url: artifact.geometryURL, options: nil)
            let (cameraNode, targetNode, cameraPosition, cameraTarget) = buildCameraNodes(for: scene)
            return ShellViewportPreview(
                artifact: artifact,
                scene: scene,
                cameraNode: cameraNode,
                targetNode: targetNode,
                cameraPosition: cameraPosition,
                cameraTarget: cameraTarget
            )
        } catch {
            throw ShellViewportPreviewError.failedToLoadScene(artifact.geometryURL.path)
        }
    }

    static func reset(_ preview: ShellViewportPreview) {
        preview.targetNode.position = preview.cameraTarget
        preview.cameraNode.position = preview.cameraPosition
        preview.cameraNode.look(at: preview.cameraTarget)
    }

    private static func buildCameraNodes(for scene: SCNScene) -> (SCNNode, SCNNode, SCNVector3, SCNVector3) {
        let (minimum, maximum) = scene.rootNode.boundingBox
        let target = SCNVector3(
            (minimum.x + maximum.x) * 0.5,
            (minimum.y + maximum.y) * 0.5,
            (minimum.z + maximum.z) * 0.5
        )

        let spanX = maximum.x - minimum.x
        let spanY = maximum.y - minimum.y
        let spanZ = maximum.z - minimum.z
        let maxSpan = max(spanX, max(spanY, spanZ))
        let radius = max(maxSpan * 0.5, 0.5)
        let distance = radius * 3.2
        let cameraPosition = SCNVector3(
            target.x + distance * 0.95,
            target.y - distance * 1.15,
            target.z + distance * 0.75
        )

        let targetNode = SCNNode()
        targetNode.position = target
        scene.rootNode.addChildNode(targetNode)

        let camera = SCNCamera()
        camera.zNear = max(distance / 100.0, 0.01)
        camera.zFar = max(distance * 20.0, 100.0)

        let cameraNode = SCNNode()
        cameraNode.camera = camera
        cameraNode.position = cameraPosition
        cameraNode.look(at: target)
        scene.rootNode.addChildNode(cameraNode)

        return (cameraNode, targetNode, cameraPosition, target)
    }
}

enum ShellViewportPreviewError: LocalizedError {
    case previewUnavailable(ShellDocumentKind)
    case failedToLoadScene(String)

    var errorDescription: String? {
        switch self {
        case .previewUnavailable(let kind):
            switch kind {
            case .recipe, .scene:
                "helper replay did not emit a previewable OBJ path"
            case .bundle:
                "bundle preview is out of scope for the current viewport slice"
            }
        case .failedToLoadScene(let path):
            "failed to load preview scene at \(path)"
        }
    }
}
