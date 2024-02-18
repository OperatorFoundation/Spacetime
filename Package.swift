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
        .package(url: "https://github.com/apple/swift-log", from: "1.5.3"),
        .package(url: "https://github.com/OperatorFoundation/Amber", from: "1.0.0"),
        .package(url: "https://github.com/OperatorFoundation/Chord", from: "0.1.4"),
        .package(url: "https://github.com/OperatorFoundation/Datable", from: "4.0.1"),
        .package(url: "https://github.com/OperatorFoundation/Parchment", from: "1.0.0"),
        .package(url: "https://github.com/OperatorFoundation/SwiftHexTools", from: "1.2.6"),
        .package(url: "https://github.com/OperatorFoundation/SwiftQueue", from: "0.1.3"),
        .package(url: "https://github.com/OperatorFoundation/Transmission", from: "1.2.11"),
        .package(url: "https://github.com/OperatorFoundation/TransmissionTypes", from: "0.0.2"),
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
