// swift-tools-version: 5.7

import PackageDescription

let package = Package(
    name: "NameResolver",
    platforms: [ .iOS(.v12), .macOS(.v10_14), ],
    products: [
        .library(
            name: "NameResolverAPI",
            targets: [ "NameResolverAPI", ]),
        .library(
            name: "NameResolverFoundation",
            targets: [ "NameResolverFoundation", ]),
        .library(
            name: "NameResolverMDNS",
            targets: [ "NameResolverMDNS", ]),
        .library(
            name: "NameResolverPosix",
            targets: [ "NameResolverPosix", ]),
        .library(
            name: "NameResolverTest",
            targets: [ "NameResolverTest", ]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-nio", branch: "main"),
    ],
    targets: [
        .target(
            name: "NameResolverAPI",
            dependencies: [ .product(name: "NIOCore", package: "swift-nio"),
                            .product(name: "NIOPosix", package: "swift-nio"), ]),
        .target(
            name: "NameResolverFoundation",
            dependencies: [ "NameResolverAPI", ]),
        .target(
            name: "NameResolverMDNS",
            dependencies: [ "NameResolverAPI", ]),
        .target(
            name: "NameResolverPosix",
            dependencies: [ "NameResolverAPI",
                            .product(name: "NIOCore", package: "swift-nio"),
                            .product(name: "NIOPosix", package: "swift-nio"), ]),
        .target(
            name: "NameResolverTest",
            dependencies: [ "NameResolverAPI", ]),
        .testTarget(
            name: "NameResolverTests",
            dependencies: [ "NameResolverAPI",
                            "NameResolverFoundation",
                            "NameResolverMDNS",
                            "NameResolverPosix",
                            "NameResolverTest",
                            .product(name: "NIOCore", package: "swift-nio"),
                            .product(name: "NIOPosix", package: "swift-nio"), ]),
    ]
)
