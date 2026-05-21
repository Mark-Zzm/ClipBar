// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ClipBar",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "ClipBar", targets: ["ClipBar"]),
        .executable(name: "CoreChecks", targets: ["CoreChecks"]),
        .library(name: "ClipboardCore", targets: ["ClipboardCore"])
    ],
    targets: [
        .target(name: "ClipboardCore"),
        .executableTarget(
            name: "ClipBar",
            dependencies: ["ClipboardCore"]
        ),
        .executableTarget(
            name: "CoreChecks",
            dependencies: ["ClipboardCore"]
        )
    ]
)
