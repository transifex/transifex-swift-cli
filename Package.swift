// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "TXCli",
    platforms: [
        .macOS(.v10_13)
    ],
    products: [
        .executable(name: "transifex",
                    targets: ["TXCli"])
    ],
    dependencies: [
        .package(name: "TransifexNative",
                 url: "https://github.com/transifex/transifex-swift",
                 .branch("devel")),
        .package(url: "https://github.com/apple/swift-argument-parser",
                 from: "0.3.0"),
    ],
    targets: [
        .target(
            name: "TXCliLib",
            dependencies: [
                .product(name: "TransifexNative",
                         package: "TransifexNative"),
                .product(name: "ArgumentParser",
                         package: "swift-argument-parser"),
            ]
        ),
        .target(
            name: "TXCli",
            dependencies: ["TXCliLib"]),
        .testTarget(
            name: "TXCliTests",
            dependencies: ["TXCliLib"]),
    ]
)
