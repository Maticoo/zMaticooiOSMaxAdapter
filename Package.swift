// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "zMaticooMAXAdapter",
    platforms: [
        .iOS(.v12)
    ],
    products: [
        .library(
            name: "zMaticooMAXAdapter",
            targets: ["zMaticooMAXAdapter"]
        )
    ],
    dependencies: [
        .package(name: "zMaticoo", url: "https://github.com/cloudadrd/zMaticooPodSpec.git", from: "2.3.1"),
        .package(
            name: "AppLovinSDK",
            url: "https://github.com/AppLovin/AppLovin-MAX-Swift-Package.git",
            from: "11.0.0"
        )
    ],
    targets: [
        .target(
            name: "zMaticooMAXAdapter",
            dependencies: [
                .product(name: "MaticooSDK", package: "zMaticoo"),
                .product(name: "AppLovinSDK", package: "AppLovinSDK")
            ],
            path: "Classes",
            publicHeadersPath: ".",
            cSettings: [
                .headerSearchPath(".")
            ]
        )
    ]
)
