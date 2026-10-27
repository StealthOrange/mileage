// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MileageCore",
    platforms: [.macOS(.v13), .iOS(.v17)],
    products: [.library(name: "MileageCore", targets: ["MileageCore"])],
    targets: [
        .target(name: "MileageCore"),
        .testTarget(name: "MileageCoreTests", dependencies: ["MileageCore"])
    ]
)
