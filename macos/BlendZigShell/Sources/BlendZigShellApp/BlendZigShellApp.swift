import SwiftUI

struct BlendZigShellApp: App {
    @State private var model = ShellAppModel()

    var body: some Scene {
        WindowGroup("blender-zig shell") {
            ShellMainView(model: model, launchMode: shellLaunchMode)
        }
    }
}
