// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "WXL",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "WXL",
            targets: ["WXL"]
        )
    ],
    dependencies: [
        // Keyboard shortcuts
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts.git", from: "2.0.0"),
        // SQLite wrapper
        .package(url: "https://github.com/stephencelis/SQLite.swift.git", from: "0.14.1"),
    ],
    targets: [
        .executableTarget(
            name: "WXL",
            dependencies: [
                .product(name: "KeyboardShortcuts", package: "KeyboardShortcuts"),
                .product(name: "SQLite", package: "SQLite.swift"),
            ],
            path: "Sources/WXL"
        ),
        .testTarget(
            name: "WXLTests",
            dependencies: ["WXL"],
            path: "Tests"
        ),
    ]
)
