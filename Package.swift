// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "RamCleaner",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "RamCleaner",
            path: "Sources/RamCleaner"
        )
    ]
)
