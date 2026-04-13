// swift-tools-version:6.0

import PackageDescription

let package = Package(
  name: "HostFeatures",
  platforms: [.iOS(.v18), .macOS(.v15)],
  products: [
    .library(name: "HostSynths", targets: ["HostSynths"]),
    .library(name: "HostPresets", targets: ["HostPresets"]),
    .library(name: "HostRoot", targets: ["HostRoot"]),
    .library(name: "HostSettings", targets: ["HostSettings"]),
    .library(name: "HostSupport", targets: ["HostSupport"])
  ],
  dependencies: [
    .package(url: "https://github.com/bradhowes/AUv3Controls", from: "1.0.0"),
    .package(url: "https://github.com/bradhowes/typedfullstate", branch: "main"),
    .package(url: "https://github.com/pointfreeco/swift-composable-architecture", from: "1.22.3"),
    .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "1.10.0"),
    .package(url: "https://github.com/pointfreeco/swift-sharing", from: "2.7.4")
  ],
  targets: [
    .target(name: "HostSynths",
            dependencies: [
              "HostSupport",
              .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
              .product(name: "TypedFullState", package: "TypedFullState")
            ]
           ),
    .target(name: "HostPresets",
            dependencies: [
              "HostSupport",
              .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
              .product(name: "TypedFullState", package: "TypedFullState")
            ]
           ),
    .target(name: "HostRoot",
            dependencies: [
              "HostSynths",
              "HostPresets",
              "HostSettings",
              "HostSupport",
              .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
              .product(name: "TypedFullState", package: "TypedFullState")
            ]
           ),
    .target(name: "HostSettings",
            dependencies: [
              "HostSupport",
              .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
            ]
           ),
    .target(name: "HostSupport",
            dependencies: [
              .product(name: "AUv3Controls", package: "AUv3Controls"),
              .product(name: "Dependencies", package: "swift-dependencies"),
              .product(name: "DependenciesMacros", package: "swift-dependencies"),
              .product(name: "Sharing", package: "swift-sharing"),
            ]
           ),
    .testTarget(
      name: "AudioUnitHostTests"
    )
  ]
)
