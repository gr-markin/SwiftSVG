// swift-tools-version:5.9

import PackageDescription

let package = Package(
    name: "SwiftSVG",
    platforms: [.macOS(.v11), .iOS(.v12), .tvOS(.v12)],
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
            dependencies: [.product(name: "ColorCode", package: "WFColorCode")],
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
