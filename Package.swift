// swift-tools-version: 6.4

import PackageDescription

let package = Package(
    name: "OpenVision",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .library(
            name: "OpenVision",
            targets: ["OpenVision"]
        )
    ],
    dependencies: [
        .package(
            url: "https://github.com/1amageek/OpenCoreMedia.git",
            branch: "main"
        ),
        .package(
            url: "https://github.com/1amageek/OpenCoreVideo.git",
            branch: "main"
        )
    ],
    targets: [
        .target(
            name: "OpenVision",
            dependencies: [
                "OpenCoreMedia",
                "OpenCoreVideo"
            ]
        ),
        .executableTarget(
            name: "OpenVisionPortableSmoke",
            dependencies: ["OpenVision"],
            path: "Tests/Runtime/OpenVisionPortableSmoke"
        ),
        .testTarget(
            name: "OpenVisionTests",
            dependencies: ["OpenVision"]
        )
    ],
    swiftLanguageModes: [.v6]
)
