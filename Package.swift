// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SudokuCore",
    defaultLocalization: "en-GB",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "SudokuCore",
            targets: ["SudokuCore"]),
    ],
    dependencies: [
        .package(url: "https://github.com/ordo-one/package-benchmark", from: "1.29.4"),
        .package(url: "https://github.com/apple/swift-collections.git", from: "1.1.0"),
        .package(url: "https://github.com/apple/swift-numerics.git", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-algorithms.git", from: "1.2.0")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "SudokuCore",
            dependencies: [
                .product(name: "Collections", package: "swift-collections"),
                .product(name: "Numerics", package: "swift-numerics"),
                .product(name: "Algorithms", package: "swift-algorithms")
            ],
            resources: [.process("Localizable.xcstrings")]),
        .testTarget(
            name: "SudokuCoreTests",
            dependencies: ["SudokuCore"],
            resources: [
                .copy("Fixtures")
            ]
        ),
        .executableTarget(
            name: "SudokuCoreBenchmarks",
            dependencies: [
                "SudokuCore",
                .product(name: "Benchmark", package: "package-benchmark")
            ],
            path: "Benchmarks/SudokuCoreBenchmarks",
            swiftSettings: [
                .unsafeFlags(["-Xlinker", "-w"])
            ],
            plugins: [
                .plugin(name: "BenchmarkPlugin", package: "package-benchmark")
            ]
        ),
    ]
)
