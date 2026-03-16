// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "Dwell",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "DwellCore", targets: ["DwellCore"]),
        .executable(name: "DwellApp", targets: ["DwellApp"])
    ],
    targets: [
        .target(
            name: "DwellCore",
            path: "Sources/DwellCore"
        ),
        .executableTarget(
            name: "DwellApp",
            dependencies: ["DwellCore"],
            path: "Sources/DwellApp",
            resources: [
                .process("Assets.xcassets")
            ]
        ),
        .testTarget(
            name: "DwellCoreTests",
            dependencies: ["DwellCore"],
            path: "Tests/DwellCoreTests"
        )
    ]
)
