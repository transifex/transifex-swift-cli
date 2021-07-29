// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "TransifexCli",
    platforms: [
        .macOS(.v10_13)
    ],
    products: [
        .executable(name: "txios-cli",
                    targets: ["TXCli"])
    ],
    dependencies: [
        .package(name: "transifex",
                 url: "https://github.com/transifex/transifex-swift",
                 from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-argument-parser",
                 from: "0.3.0"),
    ],
    targets: [
        .target(
            name: "TXCliLib",
            dependencies: [
                .product(name: "Transifex",
                         package: "transifex"),
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
