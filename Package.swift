// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "heatpeek",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "HeatPeekCore", targets: ["HeatPeekCore"]),
        .executable(name: "heatpeek", targets: ["heatpeek"]),
    ],
    targets: [
        .target(name: "HeatPeekCore"),
        .executableTarget(name: "heatpeek", dependencies: ["HeatPeekCore"]),
        .testTarget(name: "HeatPeekCoreTests", dependencies: ["HeatPeekCore"]),
    ]
)
