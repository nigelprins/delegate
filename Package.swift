// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Delegate",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "delegate", targets: ["Delegate"]),
        .executable(name: "delegate-checks", targets: ["DelegateChecks"])
    ],
    targets: [
        .target(name: "DelegateCore"),
        .executableTarget(
            name: "Delegate",
            dependencies: ["DelegateCore"],
            linkerSettings: [
                .linkedFramework("Security")
            ]
        ),
        .executableTarget(
            name: "DelegateChecks",
            dependencies: ["DelegateCore"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
