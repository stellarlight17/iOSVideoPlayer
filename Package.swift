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
        .binaryTarget(name: "HorizontalProgressBarView", url: "https://github.com/stellarlight17/HorizontalProgressBarView/releases/download/1.0.0/HorizontalProgressBarView.xcframework.zip", checksum: "55b9b1293d26b8d9acc60210fd28dc67e1bf1fa8a8d98b5f037edc5db48c831d"),
        .testTarget(
            name: "VideoPlayerTests",
            dependencies: ["VideoPlayer"]),
    ]
)
