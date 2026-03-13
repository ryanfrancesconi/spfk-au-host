// swift-tools-version: 6.2
// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi

import PackageDescription

let package = Package(
    name: "spfk-au-host",
    defaultLocalization: "en",
    platforms: [.macOS(.v13), .iOS(.v16),],
    products: [
        .library(
            name: "SPFKAUHost",
            targets: ["SPFKAUHost"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/ryanfrancesconi/spfk-utils", from: "0.0.8"),
        .package(url: "https://github.com/ryanfrancesconi/spfk-testing", from: "0.0.9"),
    ],
    targets: [
        .target(
            name: "SPFKAUHost",
            dependencies: [
                .product(name: "SPFKUtils", package: "spfk-utils"),
            ]
        ),
        .testTarget(
            name: "SPFKAUHostTests",
            dependencies: [
                .targetItem(name: "SPFKAUHost", condition: nil),
                .product(name: "SPFKTesting", package: "spfk-testing"),
            ]
        ),
    ]
)
