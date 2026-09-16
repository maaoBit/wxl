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
        // 3.x 修复 macOS 26/27 Recorder 崩溃（含 Bundle.module 断言、Swift 6.3 release 崩溃）
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts.git", from: "3.0.0"),
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
