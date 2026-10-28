// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "HarborKit",
    defaultLocalization: "en",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "HarborKit", targets: ["HarborKit"]),
    ],
    targets: [
        .target(
            name: "HarborKit",
            resources: [.process("Resources")],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
