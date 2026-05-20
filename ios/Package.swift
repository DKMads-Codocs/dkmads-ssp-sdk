// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "DKMadsSSPSDK",
    platforms: [.iOS(.v13)],
    products: [
        .library(name: "DKMadsSSPSDK", targets: ["DKMadsSSPSDK"]),
    ],
    targets: [
        .target(
            name: "DKMadsSSPSDK",
            path: "Sources/DKMadsSSPSDK",
            linkerSettings: [
                .linkedFramework("UIKit"),
                .linkedFramework("WebKit"),
                .linkedFramework("AVFoundation"),
                .linkedFramework("SafariServices"),
            ]
        ),
    ]
)
