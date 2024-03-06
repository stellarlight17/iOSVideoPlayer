// swift-tools-version: 5.8
import PackageDescription

let package = Package(
    name: "VideoPlayer",
    platforms: [ .iOS(.v15) ],
    products: [
        .library(
            name: "VideoPlayer",
            targets: ["VideoPlayer", "HorizontalProgressBarView"]),
    ],
    dependencies: [
    ],
    targets: [
        .target(
            name: "VideoPlayer", dependencies: []),
        //.binaryTarget(name: "HorizontalProgressBarView", path: "../HorizontalProgressBarView/HorizontalProgressBarView.xcframework"),
        //.binaryTarget(name: "HorizontalProgressBarView", url: "https://github.com/mayuhayomi/horizontalprogressbarview/releases/download/0.1.0/HorizontalProgressBarView.xcframework.zip", checksum: "91667cbb2c4d05a4cf1220d0eaff5fb26201d4d195354eeaa324eb2e22073927"),
        .binaryTarget(name: "HorizontalProgressBarView", url: "https://github.com/stellarlight17/HorizontalProgressBarView/releases/download/0.1.0/HorizontalProgressBarView.xcframework.zip", checksum: "55b9b1293d26b8d9acc60210fd28dc67e1bf1fa8a8d98b5f037edc5db48c831d"),
        .testTarget(
            name: "VideoPlayerTests",
            dependencies: ["VideoPlayer"]),
    ]
)
