// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "work.edwin.rawpicker",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "RawPicker", targets: ["RawPicker"])
    ],
    targets: [
        .executableTarget(
            name: "RawPicker",
            path: "rawpicker",
            resources: [
                .process("Assets.xcassets"),
                .process("Resources")
            ],
            swiftSettings: [
                .defaultIsolation(MainActor.self)
            ]
        )
    ],
    swiftLanguageModes: [.v6]
)
