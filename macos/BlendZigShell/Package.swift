// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "BlendZigShell",
    platforms: [
        .macOS(.v15),
    ],
    products: [
        .library(name: "BlendZigShellCore", targets: ["BlendZigShellCore"]),
        .executable(name: "BlendZigShell", targets: ["BlendZigShellApp"]),
    ],
    targets: [
        .target(name: "BlendZigShellCore"),
        .executableTarget(
            name: "BlendZigShellApp",
            dependencies: ["BlendZigShellCore"]
        ),
        .testTarget(
            name: "BlendZigShellCoreTests",
            dependencies: ["BlendZigShellCore"]
        ),
    ]
)
