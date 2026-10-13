// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Sofaonmac",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Sofaonmac",
            path: "Sources/Sofaonmac"
        )
    ],
    swiftLanguageModes: [.v5]
)
