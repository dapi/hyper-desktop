// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "HyperDesktop",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "HyperDesktop", targets: ["HyperDesktop"]),
    ],
    targets: [
        .executableTarget(name: "HyperDesktop"),
    ]
)
