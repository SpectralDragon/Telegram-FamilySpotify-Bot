// swift-tools-version:5.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "AdaSpotify",
    dependencies: [
        .package(url: "https://github.com/givip/Telegrammer.git", .exact( "0.5.1")),
        .package(url: "https://github.com/vapor/vapor.git", from: "3.0.0"),
        .package(url: "https://github.com/vapor/fluent-sqlite.git", from: "3.0.0"),
    ],
    targets: [
        .target(name: "AdaSpotify", dependencies: ["Vapor", "Telegrammer", "FluentSQLite"]),
    ]
)

