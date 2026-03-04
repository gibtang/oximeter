// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SpO2Monitor",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "SpO2Monitor",
            targets: ["SpO2Monitor"]),
    ],
    dependencies: [
        // Add any external dependencies here
    ],
    targets: [
        .target(
            name: "SpO2Monitor",
            dependencies: [],
            path: "SpO2Monitor",
            exclude: ["Resources/Info.plist"],
            sources: [
                "App",
                "Managers",
                "Models",
                "Utilities",
                "Views"
            ],
            resources: [
                .process("Resources")
            ]),
        .testTarget(
            name: "SpO2MonitorTests",
            dependencies: ["SpO2Monitor"],
            path: "Tests/SpO2MonitorTests"),
    ]
)
