// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription
import CompilerPluginSupport

let package = Package(
    name: "LenientCodable",
    platforms: [
        .macOS(.v10_15),
        .iOS(.v13),
        .tvOS(.v13),
        .watchOS(.v6),
        .macCatalyst(.v13)
    ],
    products: [
        .library(
            name: "LenientCodable",
            targets: ["LenientCodable"]
        ),
        .executable(
            name: "LenientCodableClient",
            targets: ["LenientCodableClient"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "602.0.0-latest"),
    ],
    targets: [
        .macro(
            name: "LenientCodableMacros",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax")
            ]
        ),
        .target(name: "LenientCodable", dependencies: ["LenientCodableMacros"]),
        .executableTarget(name: "LenientCodableClient", dependencies: ["LenientCodable"]),
        .testTarget(
            name: "LenientCodableTests",
            dependencies: [
                "LenientCodableMacros",
                .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
            ]
        ),
    ]
)
