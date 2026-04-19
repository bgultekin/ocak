// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Ocak",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/migueldeicaza/SwiftTerm.git", from: "1.2.0"),
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts.git", from: "2.0.0"),
        .package(url: "https://github.com/SimplyDanny/SwiftLintPlugins", from: "0.63.2"),
        .package(url: "https://github.com/sparkle-project/Sparkle.git", from: "2.6.0"),
    ],
    targets: [
        .executableTarget(
            name: "Ocak",
            dependencies: ["SwiftTerm", "KeyboardShortcuts", "Sparkle"],
            path: "Sources/Ocak",
            resources: [
                .copy("Resources/claude-ocak-marketplace"),
                .copy("Resources/opencode-ocak"),
                .process("Resources/ocak-menubar-icon-default.png"),
                .process("Resources/ocak-menubar-icon-active.png"),
                .process("Resources/ocak-app-icon-light.png"),
                .process("Resources/ocak-app-icon-dark.png"),
                .process("Resources/ocak-text-dark.png"),
                .process("Resources/ocak-text-light.png"),
            ],
            plugins: [
                .plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLintPlugins"),
            ]
        ),
        .testTarget(
            name: "OcakTests",
            path: "Tests/OcakTests",
            plugins: [
                .plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLintPlugins"),
            ]
        ),
    ]
)
