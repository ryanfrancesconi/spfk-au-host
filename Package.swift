// swift-tools-version: 6.2
// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi

import PackageDescription

let package = Package(
    name: "spfk-au-host",
    defaultLocalization: "en",
    platforms: [.macOS(.v12), .iOS(.v15),],
    products: [
        .library(
            name: "SPFKAUHost",
            targets: ["SPFKAUHost", "SPFKAUHostC",]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/ryanfrancesconi/spfk-base", from: "0.0.3"),
        .package(url: "https://github.com/ryanfrancesconi/spfk-utils", from: "0.0.8"),
        .package(url: "https://github.com/ryanfrancesconi/spfk-testing", from: "0.0.5"),
    ],
    targets: [
        .target(
            name: "SPFKAUHost",
            dependencies: [
                .product(name: "SPFKUtils", package: "spfk-utils"),
                .targetItem(name: "SPFKAUHostC", condition: nil),
            ]
        ),
        .target(
            name: "SPFKAUHostC",
            dependencies: [
                .product(name: "SPFKBase", package: "spfk-base"),
            ],
            publicHeadersPath: "include",
            cSettings: [
                .headerSearchPath("include_private")
            ],
            cxxSettings: [
                .headerSearchPath("include_private")
            ]
        ),
        .testTarget(
            name: "SPFKAUHostTests",
            dependencies: [
                .targetItem(name: "SPFKAUHost", condition: nil),
                .targetItem(name: "SPFKAUHostC", condition: nil),
                .product(name: "SPFKTesting", package: "spfk-testing"),
            ]
        ),
    ],
    cxxLanguageStandard: .cxx20
)
