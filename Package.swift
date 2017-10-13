// swift-tools-version:4.0
// The swift-tools-version declares the minimum version of Swift required to build this package.
import PackageDescription

let package = Package(
    name: "AsyncNetwork",
    products: [
        .library(name: "AsyncNetwork", targets: ["AsyncNetwork"])
    ],
    targets: [
        .target(
            name: "AsyncNetwork"
        )
    ],
    swiftLanguageVersions: [3, 4]
)
