import Foundation

public enum ShellPrimitiveTemplate: String, CaseIterable, Equatable, Sendable {
    case cuboid
    case cylinder
    case sphere

    public init(name: String) throws {
        guard let template = Self(rawValue: name.lowercased()) else {
            throw ShellPrimitiveTemplateError.unknownTemplate(name)
        }
        self = template
    }

    public var displayName: String {
        switch self {
        case .cuboid:
            "Cuboid"
        case .cylinder:
            "Cylinder"
        case .sphere:
            "Sphere"
        }
    }

    public var fileStem: String {
        switch self {
        case .cuboid:
            "cuboid-study"
        case .cylinder:
            "cylinder-study"
        case .sphere:
            "sphere-study"
        }
    }

    public var defaultTitle: String {
        "\(displayName) Study"
    }

    public func renderRecipeText(title: String, replayID: String, studyURL: URL) -> String {
        let outputURL = studyURL
            .deletingPathExtension()
            .appendingPathExtension("obj")
            .standardizedFileURL

        return """
        # blender-zig pipeline v1
        # Authored from the native shell as a bounded primitive-backed starter study.

        format-version=1
        id=\(replayID)
        title=\(title)
        seed=\(seedText)
        write=\(outputURL.path)
        """ + "\n"
    }

    private var seedText: String {
        switch self {
        case .cuboid:
            "cuboid:size-x=2.0,size-y=2.0,size-z=2.0,verts-x=2,verts-y=2,verts-z=2,uvs=true"
        case .cylinder:
            "cylinder:radius=1.0,height=2.0,segments=16,top-cap=true,bottom-cap=true,uvs=true"
        case .sphere:
            "sphere:radius=1.25,segments=12,rings=6,uvs=true"
        }
    }
}

public enum ShellPrimitiveTemplateError: LocalizedError, Equatable {
    case unknownTemplate(String)

    public var errorDescription: String? {
        switch self {
        case .unknownTemplate(let name):
            "unknown primitive template: \(name)"
        }
    }
}
