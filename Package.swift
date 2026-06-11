// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "GitDog",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "GitDog",
            path: "Sources/GitDog"
        )
    ]
)
