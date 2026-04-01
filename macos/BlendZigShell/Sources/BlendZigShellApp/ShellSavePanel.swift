import AppKit
import BlendZigShellCore
import UniformTypeIdentifiers

@MainActor
enum ShellSavePanel {
    static func choosePrimitiveStudyURL(for template: ShellPrimitiveTemplate) -> URL? {
        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        panel.prompt = "Create Study"
        panel.message = "Choose where to write the new primitive-backed .bzrecipe study."
        panel.nameFieldStringValue = "\(template.fileStem).bzrecipe"
        panel.allowedContentTypes = supportedContentTypes()

        guard panel.runModal() == .OK else { return nil }
        guard let url = panel.url else { return nil }
        if url.pathExtension.lowercased() == "bzrecipe" {
            return url
        }
        return url.appendingPathExtension("bzrecipe")
    }

    private static func supportedContentTypes() -> [UTType] {
        guard let recipeType = UTType(filenameExtension: "bzrecipe") else { return [] }
        return [recipeType]
    }
}
