// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CapgoCapacitorWidgetKit",
    platforms: [.iOS(.v16)],
    products: [
        .library(
            name: "CapgoCapacitorWidgetKit",
            targets: ["CapgoWidgetKitPlugin"]
        ),
        .library(
            name: "CapgoWidgetKitShared",
            targets: ["CapgoWidgetKitShared"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/ionic-team/capacitor-swift-pm.git", from: "8.0.0")
    ],
    targets: [
        .target(
            name: "CapgoWidgetKitShared",
            dependencies: [],
            path: "ios/Sources/CapgoWidgetKitPlugin",
            exclude: ["CapgoWidgetKitPlugin.swift"]
        ),
        .target(
            name: "CapgoWidgetKitPlugin",
            dependencies: [
                "CapgoWidgetKitShared",
                .product(name: "Capacitor", package: "capacitor-swift-pm"),
                .product(name: "Cordova", package: "capacitor-swift-pm")
            ],
            path: "ios/Sources/CapgoWidgetKitPlugin",
            sources: ["CapgoWidgetKitPlugin.swift"]
        ),
        .testTarget(
            name: "CapgoWidgetKitPluginTests",
            dependencies: ["CapgoWidgetKitShared"],
            path: "ios/Tests/CapgoWidgetKitPluginTests"
        )
    ]
)
