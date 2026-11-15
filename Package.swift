// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DNKPiu",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "DNKPiu", targets: ["DNKPiu"]),
        .library(name: "PiuCore", targets: ["PiuCore"])
    ],
    targets: [
        .target(name: "PiuCore"),
        .executableTarget(name: "DNKPiu", dependencies: ["PiuCore"]),
    ],
    swiftLanguageModes: [.v5]
)

