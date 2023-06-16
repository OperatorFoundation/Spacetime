// swift-tools-version:5.8
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Spacetime",
    platforms: [.macOS(.v13),
                .iOS(.v16)],
    products: [
        .library(
            name: "Spacetime",
            targets: ["Spacetime"]),
        .library(
            name: "Universe",
            targets: ["Universe"]),
        .library(
            name: "Simulation",
            targets: ["Simulation"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-log.git", from: "1.0.0"),

        .package(url: "https://github.com/OperatorFoundation/Amber", branch: "main"),
        .package(url: "https://github.com/OperatorFoundation/Chord", branch: "main"),
        .package(url: "https://github.com/OperatorFoundation/Datable", branch: "main"),
        .package(url: "https://github.com/OperatorFoundation/Parchment", branch: "main"),
        .package(url: "https://github.com/OperatorFoundation/SwiftHexTools", branch: "main"),
        .package(url: "https://github.com/OperatorFoundation/SwiftQueue", branch: "main"),
        .package(url: "https://github.com/OperatorFoundation/Transmission", branch: "main"),
        .package(url: "https://github.com/OperatorFoundation/TransmissionTypes", branch: "main"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "Spacetime",
            dependencies: [
                .product(name: "ParchmentFile", package: "Parchment"),
                
                "Datable",
                "SwiftHexTools",
                "Transmission",
            ]),
        
        .target(
            name: "Universe",
            dependencies: [
                .product(name: "Logging", package: "swift-log"),
                .product(name: "ParchmentFile", package: "Parchment"),

                "Amber",
                "Chord",
                "Datable",
                "SwiftHexTools",
                "SwiftQueue",
                "Spacetime",
                "TransmissionTypes",
            ]),
        
        .target(
            name: "Simulation",
            dependencies: [
                .product(name: "Logging", package: "swift-log"),
                .product(name: "ParchmentFile", package: "Parchment"),

                "Amber",
                "Chord",
                "Spacetime",
                "SwiftQueue",
                "Transmission",
            ]),
        
        .testTarget(
            name: "SpacetimeTests",
            dependencies: ["Universe", "Simulation", "Datable", "Spacetime"]),
    ],
    swiftLanguageVersions: [.v5]
)
