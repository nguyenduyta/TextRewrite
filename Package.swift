// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TextRewriter",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "TextRewriter",
            path: "Sources/TextRewriter",
            linkerSettings: [.linkedFramework("Carbon")]
        ),
    ]
)
