// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "CrewP2P",
    platforms: [.iOS("15.0")],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "CrewP2P",
            targets: ["CrewP2P"]),
    ],
    dependencies: [
        .package(url: "https://github.com/microsoft/appcenter-sdk-apple.git", .upToNextMajor(from: "5.0.4")),
        .package(url: "https://dev.azure.com/LHG-Crew/P2PFramework/_git/P2PGraph", branch: "main")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "CrewP2P",
            dependencies: [
                .product(name: "AppCenterAnalytics", package: "appcenter-sdk-apple"),
                .product(name: "AppCenterCrashes", package: "appcenter-sdk-apple"),
                .product(name: "AppCenterDistribute", package: "appcenter-sdk-apple"),
                .product(name: "DirectedGraph", package: "P2PGraph"),
            ],
            path: "Sources")
    ]
)
