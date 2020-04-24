// swift-tools-version:5.0

import PackageDescription

let package = Package(
    name: "SwiftSVG",
    platforms: [.macOS(.v10_14), .iOS(.v8), .tvOS(.v9)],
    products: [
        .library(
            name: "SwiftSVG",
            targets: ["SwiftSVG"]
        ),
    ],
    dependencies: [
      .package(url: "https://github.com/1024jp/WFColorCode.git", from: "2.5.0")
    ],
    targets: [
        .target(
            name: "SwiftSVG",
            dependencies: ["ColorCode"],
            path: "SwiftSVG"
        ),
        .testTarget(
            name: "SwiftSVGTests",
            dependencies: ["SwiftSVG"],
            path: "SwiftSVGTests"
        ),
    ],
    swiftLanguageVersions: [.v5]
)
