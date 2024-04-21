// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "Features",
  platforms: [.iOS(.v16), .macOS(.v14)],
  products: [
    .library(name: "Models", targets: ["Models"])
  ],
  dependencies: [
    // .package(url: "https://github.com/bradhowes/SF2Lib", from: "5.0.0")
    .package(name: "SF2Lib", path: "/Users/howes/src/Mine/SF2Lib"),
    .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "1.2.0")
  ],
  targets: [
    // Targets are the basic building blocks of a package, defining a module or a test suite.
    // Targets can depend on other targets in this package and products from dependencies.
    .target(
      name: "SoundFonts2Lib",
      dependencies: [
        .product(name: "Engine", package: "SF2Lib", condition: .none),
        .product(name: "Dependencies", package: "swift-dependencies", condition: .none),
      ]
    ),
    .target(
      name: "Extensions"
    ),
    .target(
      name: "Models",
      dependencies: [
        .targetItem(name: "Extensions", condition: .none),
        .targetItem(name: "SF2Files", condition: .none),
        .product(name: "Dependencies", package: "swift-dependencies", condition: .none),
      ]
    ),
    .target(
      name: "SF2LibAU",
      dependencies: [.product(name: "Engine", package: "SF2Lib", condition: .none)],
      swiftSettings: [.interoperabilityMode(.Cxx)]
    ),
    .target(name: "SF2Files", resources: [.process("Resources")]),
    .testTarget(
      name: "SoundFonts2LibTests",
      dependencies: [
        "SoundFonts2Lib",
        .product(name: "Dependencies", package: "swift-dependencies", condition: .none)
      ]
    ),
    .testTarget(
      name: "ModelsTests",
      dependencies: [
        "Models",
        .product(name: "Dependencies", package: "swift-dependencies", condition: .none)
      ]
    )
  ]
)
