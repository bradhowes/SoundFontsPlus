// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "Features",
  platforms: [.iOS(.v17), .macOS(.v14)],
  products: [
    .library(name: "AppFeature", targets: ["AppFeature"]),
    .library(name: "SoundFontListFeature", targets: ["SoundFontListFeature"]),
    .library(name: "PresetListFeature", targets: ["PresetListFeature"]),
    .library(name: "SoundFontEditorFeature", targets: ["SoundFontEditorFeature"]),
    .library(name: "Extensions", targets: ["Extensions"]),
    .library(name: "Models", targets: ["Models"]),
    .library(name: "SF2ResourceFiles", targets: ["SF2ResourceFiles"]),
    .library(name: "SwiftUISupport", targets: ["SwiftUISupport"])
  ],
  dependencies: [
    // .package(url: "https://github.com/bradhowes/SF2Lib", from: "5.0.0")
    .package(name: "SF2Lib", path: "/Users/howes/src/Mine/SF2Lib"),
    .package(url: "https://github.com/pointfreeco/swift-composable-architecture", from: "1.10.4"),
    .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "1.2.2"),
    .package(url: "https://github.com/tgrapperon/swift-dependencies-additions", from: "1.0.1"),
    .package(url: "https://github.com/bradhowes/SplitView", from: "3.5.2")
  ],
  targets: [
    .target(
      name: "SoundFonts2Lib",
      dependencies: [
        .product(name: "Engine", package: "SF2Lib"),
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
        .product(name: "Dependencies", package: "swift-dependencies")
      ]
    ),
    .target(
      name: "AppFeature",
      dependencies: [
        .targetItem(name: "SoundFontListFeature", condition: .none),
        .targetItem(name: "PresetListFeature", condition: .none),
        .targetItem(name: "Models", condition: .none),
        .targetItem(name: "SF2ResourceFiles", condition: .none),
        .targetItem(name: "SwiftUISupport", condition: .none),
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
        .product(name: "Dependencies", package: "swift-dependencies"),
        .product(name: "DependenciesAdditions", package: "swift-dependencies-additions"),
        .product(name: "SplitView", package: "SplitView")
      ]
    ),
    .target(
      name: "SoundFontListFeature",
      dependencies: [
        .targetItem(name: "Models", condition: .none),
        .targetItem(name: "SF2ResourceFiles", condition: .none),
        .targetItem(name: "SwiftUISupport", condition: .none),
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
        .product(name: "Dependencies", package: "swift-dependencies"),
        .product(name: "DependenciesAdditions", package: "swift-dependencies-additions"),
      ]
    ),
    .target(
      name: "PresetListFeature",
      dependencies: [
        .targetItem(name: "Models", condition: .none),
        .targetItem(name: "SF2ResourceFiles", condition: .none),
        .targetItem(name: "SwiftUISupport", condition: .none),
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
        .product(name: "Dependencies", package: "swift-dependencies"),
        .product(name: "DependenciesAdditions", package: "swift-dependencies-additions"),
      ]
    ),
    .target(
      name: "SoundFontEditorFeature",
      dependencies: [
        .targetItem(name: "Models", condition: .none),
        .targetItem(name: "SF2ResourceFiles", condition: .none),
        .targetItem(name: "SwiftUISupport", condition: .none),
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
      ]
    ),
    .target(
      name: "SwiftUISupport",
      dependencies: [
        .target(name: "Models")
      ]
    ),
    .target(
      name: "Models",
      dependencies: [
        .targetItem(name: "Extensions", condition: .none),
        .targetItem(name: "SF2ResourceFiles", condition: .none),
        .product(name: "Dependencies", package: "swift-dependencies"),
        .product(name: "DependenciesAdditions", package: "swift-dependencies-additions")
      ]
    ),
    .target(
      name: "SF2ResourceFiles",
      dependencies: [
        .product(name: "Engine", package: "SF2Lib"),
        .product(name: "Dependencies", package: "swift-dependencies"),
        .product(name: "DependenciesAdditions", package: "swift-dependencies-additions")
      ],
      resources: [.process("Resources")]
    ),
    .target(
      name: "Extensions",
      dependencies: [
        .product(name: "Dependencies", package: "swift-dependencies"),
        .product(name: "DependenciesMacros", package: "swift-dependencies"),
        .product(name: "DependenciesAdditions", package: "swift-dependencies-additions")
      ]
    ),
    .target(
      name: "SF2LibAU",
      dependencies: [.product(name: "Engine", package: "SF2Lib")]
    ),
    .testTarget(
      name: "SoundFonts2LibTests",
      dependencies: [
        "SoundFonts2Lib",
        .product(name: "Dependencies", package: "swift-dependencies", condition: .none),
        .product(name: "DependenciesAdditions", package: "swift-dependencies-additions")
      ]
    ),
    .testTarget(
      name: "ModelsTests",
      dependencies: [
        "Models",
        .product(name: "Dependencies", package: "swift-dependencies", condition: .none),
        .product(name: "Engine", package: "SF2Lib", condition: .none)
      ]
    ),
    .testTarget(
      name: "SF2ResourceFilesTests",
      dependencies: [
        "SF2ResourceFiles",
        .product(name: "Engine", package: "SF2Lib", condition: .none)
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
