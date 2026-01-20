// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "CardIO",
    platforms: [.iOS(.v12)],
    products: [
        .library(
            name: "CardIO",
            targets: ["CardIO", "libCardIO", "libopencv_core", "libopencv_imgproc"]
        )
    ],
    targets: [
        .target(
            name: "CardIO",
            path: "CardIO",
            publicHeadersPath: ".",
            linkerSettings: [
              .linkedLibrary("c++")
            ]
        ),
        .binaryTarget(
            name: "libCardIO",
            path: "Frameworks/libCardIO.xcframework"
        ),
        .binaryTarget(
            name: "libopencv_core",
            path: "Frameworks/libopencv_core.xcframework"
        ),
        .binaryTarget(
            name: "libopencv_imgproc",
            path: "Frameworks/libopencv_imgproc.xcframework"
        )
    ]
)



