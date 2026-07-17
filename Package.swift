// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "MeteoBaras",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "MeteoBaras",
            path: "Sources/MeteoBaras"
        )
    ]
)
