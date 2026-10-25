// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "ScrcpyStudio",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "ScrcpyStudio", targets: ["ScrcpyStudio"]),
    ],
    targets: [
        .executableTarget(name: "ScrcpyStudio", path: "Sources"),
    ],
    swiftLanguageVersions: [.v5]
)
