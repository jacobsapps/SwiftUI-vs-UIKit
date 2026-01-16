// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "PerformanceShared",
    platforms: [
        .iOS(.v26)
    ],
    products: [
        .library(name: "PerformanceShared", targets: ["PerformanceShared"])
    ],
    targets: [
        .target(name: "PerformanceShared")
    ]
)
