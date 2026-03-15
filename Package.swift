// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "HandmeCore",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "HandmeCore", targets: ["HandmeCore"]),
        .executable(name: "handme", targets: ["handme"]),
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "7.0.0"),
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0"),
    ],
    targets: [
        .target(
            name: "HandmeCore",
            dependencies: [.product(name: "GRDB", package: "GRDB.swift")]
        ),
        .executableTarget(
            name: "handme",
            dependencies: [
                "HandmeCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        .testTarget(
            name: "HandmeCoreTests",
            dependencies: ["HandmeCore"]
        ),
    ]
)
