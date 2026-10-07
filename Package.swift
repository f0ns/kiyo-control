// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "KiyoControl",
    platforms: [.macOS("15.0")],
    products: [
        .executable(name: "KiyoControl", targets: ["KiyoControl"]),
        .executable(name: "kiyoctl", targets: ["kiyoctl"]),
        .library(name: "KiyoKit", targets: ["KiyoKit"]),
    ],
    targets: [
        .target(name: "CUVC", linkerSettings: [.linkedFramework("IOKit"), .linkedFramework("CoreFoundation")]),
        .target(name: "KiyoKit", dependencies: ["CUVC"]),
        .executableTarget(name: "kiyoctl", dependencies: ["KiyoKit"]),
        .executableTarget(name: "KiyoControl", dependencies: ["KiyoKit"]),
        .testTarget(name: "KiyoKitTests", dependencies: ["KiyoKit"]),
    ]
)
