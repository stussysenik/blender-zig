import AppKit
import UniformTypeIdentifiers

@MainActor
enum ShellOpenPanel {
    static func chooseDocumentURL() -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.treatsFilePackagesAsDirectories = false
        panel.prompt = "Open"
        panel.message = "Choose a .bzrecipe, .bzscene, or .bzbundle to replay through the bundled Zig runtime."
        panel.allowedContentTypes = supportedContentTypes()

        guard panel.runModal() == .OK else { return nil }
        return panel.url
    }

    private static func supportedContentTypes() -> [UTType] {
        var types: [UTType] = []
        if let recipeType = UTType(filenameExtension: "bzrecipe") {
            types.append(recipeType)
        }
        if let sceneType = UTType(filenameExtension: "bzscene") {
            types.append(sceneType)
        }
        if let bundleType = UTType(filenameExtension: "bzbundle", conformingTo: .package) {
            types.append(bundleType)
        }
        return types
    }
}
