// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import CompilerPluginSupport
import PackageDescription

let package = Package(
  name: "Features",
  platforms: [.iOS(.v18), .macOS(.v15)],
  products: [
    .library(name: "AppFeature", targets: ["AppFeature"]),
    .library(name: "EffectsFeature", targets: ["EffectsFeature"]),
    .library(name: "Extensions", targets: ["Extensions"]),
    .library(name: "KeyboardFeature", targets: ["KeyboardFeature"]),
    .library(name: "Models", targets: ["Models"]),
    .library(name: "PresetsFeature", targets: ["PresetsFeature"]),
    .library(name: "SF2ResourceFiles", targets: ["SF2ResourceFiles"]),
    .library(name: "SoundFontsFeature", targets: ["SoundFontsFeature"]),
    .library(name: "SwiftUISupport", targets: ["SwiftUISupport"]),
    .library(name: "SettingsFeature", targets: ["SettingsFeature"]),
    .library(name: "TagsFeature", targets: ["TagsFeature"]),
    .library(name: "ToolBarFeature", targets: ["ToolBarFeature"]),
    .library(name: "TuningFeature", targets: ["TuningFeature"]),
    .library(name: "Utils", targets: ["Utils"])
  ],
  dependencies: [
    // .package(url: "https://github.com/bradhowes/SF2Lib", from: "5.0.0")
    .package(name: "SF2Lib", path: "/Users/howes/src/Mine/SF2Lib"),
    .package(url: "https://github.com/bradhowes/brh-splitview", from: "1.0.3"),
    .package(name: "AUv3Controls", path: "/Users/howes/src/Mine/AUv3Controls"),
    // .package(url: "https://github.com/bradhowes/AUv3Controls", from: "0.15.1"),
    .package(url: "https://github.com/groue/GRDB.swift", from: "7.0.0"),
    .package(url: "https://github.com/apple/swift-algorithms", from: "1.2.0"),
    .package(url: "https://github.com/pointfreeco/sharing-grdb", from: "0.2.2"),
    .package(url: "https://github.com/pointfreeco/swift-composable-architecture", from: "1.17.0"),
    .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "1.4.1"),
    .package(url: "https://github.com/pointfreeco/swift-sharing", from: "2.0.0"),
    .package(url: "https://github.com/pointfreeco/swift-snapshot-testing", from: "1.18.0"),
    .package(url: "https://github.com/pointfreeco/swift-tagged", from: "0.10.0"),
    .package(url: "https://github.com/CrazyFanFan/FileHash", from: "0.0.1"),
  ],
  targets: [
    .target(
      name: "Utils",
      dependencies: [
        .product(name: "Sharing", package: "swift-sharing", condition: .none),
      ]
    ),
    .target(
      name: "SoundFonts2Lib",
      dependencies: [
        .product(name: "Engine", package: "SF2Lib"),
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
        .product(name: "Dependencies", package: "swift-dependencies")
      ]
    ),
    .target(
      name: "TuningFeature",
      dependencies: [
        .targetItem(name: "Utils", condition: .none),
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
        .product(name: "Dependencies", package: "swift-dependencies")
      ]
    ),
    .target(
      name: "KeyboardFeature",
      dependencies: [
        .targetItem(name: "Extensions", condition: .none),
        .targetItem(name: "SwiftUISupport", condition: .none),
        .targetItem(name: "Utils", condition: .none),
        .product(name: "Algorithms", package: "swift-algorithms"),
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
        .product(name: "Dependencies", package: "swift-dependencies")
      ]
    ),
    .target(
      name: "SettingsFeature",
      dependencies: [
        .targetItem(name: "Utils", condition: .none),
        .targetItem(name: "KeyboardFeature", condition: .none),
        .targetItem(name: "TuningFeature", condition: .none),
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
        .product(name: "Dependencies", package: "swift-dependencies")
      ]
    ),
    .target(
      name: "EffectsFeature",
      dependencies: [
        .targetItem(name: "DelayFeature", condition: .none),
        .targetItem(name: "Extensions", condition: .none),
        .targetItem(name: "Models", condition: .none),
        .targetItem(name: "ReverbFeature", condition: .none),
        .targetItem(name: "SwiftUISupport", condition: .none),
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
        .product(name: "Dependencies", package: "swift-dependencies")
      ]
    ),
    .target(
      name: "AppFeature",
      dependencies: [
        .targetItem(name: "DelayFeature", condition: .none),
        .targetItem(name: "EffectsFeature", condition: .none),
        .targetItem(name: "Extensions", condition: .none),
        .targetItem(name: "Models", condition: .none),
        .targetItem(name: "PresetsFeature", condition: .none),
        .targetItem(name: "ReverbFeature", condition: .none),
        .targetItem(name: "SettingsFeature", condition: .none),
        .targetItem(name: "SF2ResourceFiles", condition: .none),
        .targetItem(name: "SoundFontsFeature", condition: .none),
        .targetItem(name: "SwiftUISupport", condition: .none),
        .targetItem(name: "TagsFeature", condition: .none),
        .targetItem(name: "ToolBarFeature", condition: .none),
        .product(name: "BRHSplitView", package: "brh-splitview"),
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
        .product(name: "Dependencies", package: "swift-dependencies")
      ]
    ),
    .target(
      name: "SoundFontsFeature",
      dependencies: [
        .targetItem(name: "Extensions", condition: .none),
        .targetItem(name: "Models", condition: .none),
        .targetItem(name: "SF2ResourceFiles", condition: .none),
        .targetItem(name: "SwiftUISupport", condition: .none),
        .targetItem(name: "TagsFeature", condition: .none),
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
        .product(name: "Dependencies", package: "swift-dependencies")
      ]
    ),
    .target(
      name: "DelayFeature",
      dependencies: [
        .targetItem(name: "Extensions", condition: .none),
        .targetItem(name: "Models", condition: .none),
        .targetItem(name: "SF2ResourceFiles", condition: .none),
        .targetItem(name: "SwiftUISupport", condition: .none),
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
        .product(name: "Dependencies", package: "swift-dependencies"),
        .product(name: "GRDB", package: "GRDB.swift"),
        .product(name: "Sharing", package: "swift-sharing", condition: .none),
        .product(name: "SharingGRDB", package: "sharing-grdb", condition: .none),
        .product(name: "Tagged", package: "swift-tagged"),
        .product(name: "AUv3Controls", package: "AUv3Controls")
      ]
    ),
    .target(
      name: "ReverbFeature",
      dependencies: [
        .targetItem(name: "Extensions", condition: .none),
        .targetItem(name: "Models", condition: .none),
        .targetItem(name: "SF2ResourceFiles", condition: .none),
        .targetItem(name: "SwiftUISupport", condition: .none),
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
        .product(name: "Dependencies", package: "swift-dependencies"),
        .product(name: "GRDB", package: "GRDB.swift"),
        .product(name: "Sharing", package: "swift-sharing", condition: .none),
        .product(name: "SharingGRDB", package: "sharing-grdb", condition: .none),
        .product(name: "Tagged", package: "swift-tagged"),
        .product(name: "AUv3Controls", package: "AUv3Controls")
      ]
    ),
    .target(
      name: "TagsFeature",
      dependencies: [
        .targetItem(name: "Extensions", condition: .none),
        .targetItem(name: "Models", condition: .none),
        .targetItem(name: "SF2ResourceFiles", condition: .none),
        .targetItem(name: "SwiftUISupport", condition: .none),
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
        .product(name: "Dependencies", package: "swift-dependencies"),
        .product(name: "GRDB", package: "GRDB.swift"),
        .product(name: "Sharing", package: "swift-sharing", condition: .none),
        .product(name: "SharingGRDB", package: "sharing-grdb", condition: .none),
        .product(name: "Tagged", package: "swift-tagged")
      ]
    ),
    .target(
      name: "PresetsFeature",
      dependencies: [
        .targetItem(name: "Extensions", condition: .none),
        .targetItem(name: "Models", condition: .none),
        .targetItem(name: "SF2ResourceFiles", condition: .none),
        .targetItem(name: "SwiftUISupport", condition: .none),
        .product(name: "Algorithms", package: "swift-algorithms"),
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
        .product(name: "GRDB", package: "GRDB.swift"),
        .product(name: "Sharing", package: "swift-sharing", condition: .none),
        .product(name: "SharingGRDB", package: "sharing-grdb", condition: .none),
      ]
    ),
    .target(
      name: "ToolBarFeature",
      dependencies: [
        .targetItem(name: "Extensions", condition: .none),
        .targetItem(name: "KeyboardFeature", condition: .none),
        .targetItem(name: "SettingsFeature", condition: .none),
        .targetItem(name: "SwiftUISupport", condition: .none),
        .targetItem(name: "Utils", condition: .none),
        .product(name: "Algorithms", package: "swift-algorithms"),
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
        .product(name: "Dependencies", package: "swift-dependencies")
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
        .product(name: "Dependencies", package: "swift-dependencies"),
        .product(name: "FileHash", package: "FileHash"),
        .product(name: "GRDB", package: "GRDB.swift"),
        .product(name: "Sharing", package: "swift-sharing", condition: .none),
        .product(name: "SharingGRDB", package: "sharing-grdb", condition: .none),
        .product(name: "Tagged", package: "swift-tagged")
      ]
    ),
    .target(
      name: "SF2ResourceFiles",
      dependencies: [
        .product(name: "Engine", package: "SF2Lib"),
        .product(name: "Dependencies", package: "swift-dependencies"),
        .product(name: "DependenciesTestSupport", package: "swift-dependencies", condition: .none)
      ],
      resources: [.process("Resources")]
    ),
    .target(
      name: "Extensions",
      dependencies: [
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
        .product(name: "Dependencies", package: "swift-dependencies"),
        .product(name: "DependenciesMacros", package: "swift-dependencies"),
        .product(name: "DependenciesTestSupport", package: "swift-dependencies", condition: .none)
      ]
    ),
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
        .product(name: "SharingGRDB", package: "sharing-grdb", condition: .none),
        .product(name: "DependenciesTestSupport", package: "swift-dependencies", condition: .none)
        // .product(name: "Engine", package: "SF2Lib", condition: .none)
      ]
    ),
    .testTarget(
      name: "PresetsFeatureTests",
      dependencies: [
        "PresetsFeature",
        "Models",
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
        .product(name: "Dependencies", package: "swift-dependencies", condition: .none),
        .product(name: "DependenciesTestSupport", package: "swift-dependencies", condition: .none),
        .product(name: "SharingGRDB", package: "sharing-grdb", condition: .none),
        .product(name: "SnapshotTesting", package: "swift-snapshot-testing", condition: .none)
      ]
    ),
    .testTarget(
      name: "SoundFontsFeatureTests",
      dependencies: [
        "SoundFontsFeature",
        "Models",
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
        .product(name: "Dependencies", package: "swift-dependencies", condition: .none),
        .product(name: "DependenciesTestSupport", package: "swift-dependencies", condition: .none),
        .product(name: "SharingGRDB", package: "sharing-grdb", condition: .none),
        .product(name: "SnapshotTesting", package: "swift-snapshot-testing", condition: .none)
      ]
    ),
    .testTarget(
      name: "TagsFeatureTests",
      dependencies: [
        "TagsFeature",
        "Models",
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
        .product(name: "Dependencies", package: "swift-dependencies", condition: .none),
        .product(name: "DependenciesTestSupport", package: "swift-dependencies", condition: .none),
        .product(name: "SharingGRDB", package: "sharing-grdb", condition: .none),
        .product(name: "SnapshotTesting", package: "swift-snapshot-testing", condition: .none)
      ]
    ),
    .testTarget(
      name: "ToolBarFeatureTests",
      dependencies: [
        "ToolBarFeature",
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
        .product(name: "Dependencies", package: "swift-dependencies", condition: .none),
        .product(name: "DependenciesTestSupport", package: "swift-dependencies", condition: .none),
        .product(name: "SharingGRDB", package: "sharing-grdb", condition: .none),
        .product(name: "SnapshotTesting", package: "swift-snapshot-testing", condition: .none)
      ]
    ),
    .testTarget(
      name: "SF2ResourceFilesTests",
      dependencies: [
        "SF2ResourceFiles",
        .product(name: "Engine", package: "SF2Lib", condition: .none)
      ]
    ),
    .testTarget(
      name: "UtilsTests",
      dependencies: [
        "Utils"
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
