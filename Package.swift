// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ShieldKit",
    platforms: [
        .iOS(.v15),
        .macOS(.v12),
    ],
    products: [
        .library(name: "ShieldKit", targets: ["ShieldKit"]),
    ],
    targets: [
        .target(name: "ShieldKit"),
        .testTarget(name: "ShieldKitTests", dependencies: ["ShieldKit"]),
    ]
)
