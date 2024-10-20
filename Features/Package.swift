// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "Features",
  platforms: [.iOS(.v18), .macOS(.v15)],
  products: [
    .library(name: "AppFeature", targets: ["AppFeature"]),
    .library(name: "SoundFontsFeature", targets: ["SoundFontsFeature"]),
    .library(name: "PresetsFeature", targets: ["PresetsFeature"]),
    .library(name: "TagsFeature", targets: ["TagsFeature"]),
    .library(name: "Extensions", targets: ["Extensions"]),
    .library(name: "Models", targets: ["Models"]),
    .library(name: "SF2ResourceFiles", targets: ["SF2ResourceFiles"]),
    .library(name: "SwiftUISupport", targets: ["SwiftUISupport"])
  ],
  dependencies: [
    // .package(url: "https://github.com/bradhowes/SF2Lib", from: "5.0.0")
    .package(name: "SF2Lib", path: "/Users/howes/src/Mine/SF2Lib"),
    .package(url: "https://github.com/apple/swift-algorithms", from: "1.2.0"),
    .package(url: "https://github.com/pointfreeco/swift-composable-architecture", from: "1.15.0"),
    .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "1.4.1"),
    .package(url: "https://github.com/pointfreeco/swift-tagged", from: "0.10.0"),
    // .package(url: "https://github.com/bradhowes/SplitView", from: "3.5.2"),
    .package(url: "https://github.com/vadymmarkov/Fakery", from: "5.0.0"),
    .package(url: "https://github.com/CrazyFanFan/FileHash", from: "0.0.1")
  ],
  targets: [
    .target(
      name: "SoundFonts2Lib",
      dependencies: [
        // .product(name: "Engine", package: "SF2Lib"),
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
        .product(name: "Dependencies", package: "swift-dependencies")
      ]
    ),
    .target(
      name: "AppFeature",
      dependencies: [
        .targetItem(name: "TagsFeature", condition: .none),
        .targetItem(name: "Models", condition: .none),
        .targetItem(name: "SF2ResourceFiles", condition: .none),
        .targetItem(name: "SwiftUISupport", condition: .none),
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
        .product(name: "Dependencies", package: "swift-dependencies"),
      ]
    ),
    .target(
      name: "SoundFontsFeature",
      dependencies: [
        .targetItem(name: "Models", condition: .none),
        .targetItem(name: "SF2ResourceFiles", condition: .none),
        .targetItem(name: "SwiftUISupport", condition: .none),
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
        .product(name: "Dependencies", package: "swift-dependencies")
      ]
    ),
    .target(
      name: "TagsFeature",
      dependencies: [
        .targetItem(name: "Models", condition: .none),
        .targetItem(name: "SF2ResourceFiles", condition: .none),
        .targetItem(name: "SwiftUISupport", condition: .none),
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
        .product(name: "Dependencies", package: "swift-dependencies"),
        .product(name: "Tagged", package: "swift-tagged")
      ]
    ),
    .target(
      name: "PresetsFeature",
      dependencies: [
        .targetItem(name: "Models", condition: .none),
        .targetItem(name: "SF2ResourceFiles", condition: .none),
        .targetItem(name: "SwiftUISupport", condition: .none),
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
        .product(name: "Dependencies", package: "swift-dependencies"),
        .product(name: "Algorithms", package: "swift-algorithms")
      ]
    ),
    .target(
      name: "SwiftUISupport",
      dependencies: [
        .target(name: "Models"),
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
      ]
    ),
    .target(
      name: "Models",
      dependencies: [
        .targetItem(name: "Extensions", condition: .none),
        .targetItem(name: "SF2ResourceFiles", condition: .none),
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
        .product(name: "Dependencies", package: "swift-dependencies"),
        .product(name: "Fakery", package: "Fakery"),
        .product(name: "FileHash", package: "FileHash"),
        .product(name: "Tagged", package: "swift-tagged")
      ]
    ),
    .target(
      name: "SF2ResourceFiles",
      dependencies: [
        .product(name: "Engine", package: "SF2Lib"),
        .product(name: "Dependencies", package: "swift-dependencies"),
      ],
      resources: [.process("Resources")]
    ),
    .target(
      name: "Extensions",
      dependencies: [
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
        .product(name: "Dependencies", package: "swift-dependencies"),
        .product(name: "DependenciesMacros", package: "swift-dependencies"),
      ]
    ),
//    .target(
//      name: "SF2LibAU",
//      dependencies: [.product(name: "Engine", package: "SF2Lib")]
//    ),
    // Tests
    .testTarget(
      name: "SoundFonts2LibTests",
      dependencies: [
        "SoundFonts2Lib",
        .product(name: "Dependencies", package: "swift-dependencies", condition: .none),
      ]
    ),
    .testTarget(
      name: "ModelsTests",
      dependencies: [
        "Models",
        .product(name: "Dependencies", package: "swift-dependencies", condition: .none),
        // .product(name: "Engine", package: "SF2Lib", condition: .none)
      ]
    ),
    .testTarget(
      name: "SF2ResourceFilesTests",
      dependencies: [
        "SF2ResourceFiles",
        // .product(name: "Engine", package: "SF2Lib", condition: .none)
      ]
    )
  ]
)

// The SF2Lib Engine product requires this for everything it touches, so just do every target.
for target in package.targets {
  var settings = target.swiftSettings ?? []
  settings.append(.interoperabilityMode(.Cxx))
  settings.append(.enableExperimentalFeature("StrictConcurrency"))
  target.swiftSettings = settings
}
