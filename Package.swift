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
        .library(
            name: "SPFKAUHostTesting",
            targets: ["SPFKAUHostTesting"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/ryanfrancesconi/spfk-audio-base", from: "1.6.1"),
        .package(url: "https://github.com/ryanfrancesconi/spfk-utils", from: "1.6.1"),
        .package(url: "https://github.com/ryanfrancesconi/spfk-testing", from: "1.1.0"),
    ],
    targets: [
        .target(
            name: "SPFKAUHost",
            dependencies: [
                .product(name: "SPFKAudioBase", package: "spfk-audio-base"),
                .product(name: "SPFKUtils", package: "spfk-utils"),
            ]
        ),
        .target(
            name: "SPFKAUHostTesting",
            dependencies: [
                .targetItem(name: "SPFKAUHost", condition: nil),
                .product(name: "SPFKAudioBase", package: "spfk-audio-base"),
            ]
        ),
        .testTarget(
            name: "SPFKAUHostTests",
            dependencies: [
                .targetItem(name: "SPFKAUHost", condition: nil),
                .targetItem(name: "SPFKAUHostTesting", condition: nil),
                .product(name: "SPFKTesting", package: "spfk-testing"),
            ]
        ),
    ]
)
