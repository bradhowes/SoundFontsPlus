// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let alwaysShowTutorial = false
let alwaysShowChanges = false
let useLocalSF2Lib = false

let globalSwiftSettings: [SwiftSetting] = [
  .enableExperimentalFeature("StrictConcurrency"),
  .interoperabilityMode(.Cxx),
  .strictMemorySafety(),
  .swiftLanguageMode(.v6)
]

let sf2Lib: Package.Dependency = useLocalSF2Lib ? .package(
  name: "SF2Lib",
  path: "/Users/howes/src/Mine/SF2Lib"
) : .package(
  url: "https://github.com/bradhowes/SF2Lib",
  from: "8.3.2"
)

let package = Package(
  name: "Features",
  platforms: [.iOS(.v18)],
  products: [
    .library(name: "AppReview", targets: ["AppReview"]),
    .library(name: "BaseSupport", targets: ["BaseSupport"]),
    .library(name: "ChangesFeature", targets: ["ChangesFeature"]),
    .library(name: "DelayEffect", targets: ["DelayEffect"]),
    .library(name: "FeatureSupport", targets: ["FeatureSupport"]),
    .library(name: "Keyboard", targets: ["Keyboard"]),
    .library(name: "Models", targets: ["Models"]),
    .library(name: "ReverbEffect", targets: ["ReverbEffect"]),
    .library(name: "SF2Resources", targets: ["SF2Resources"]),
    .library(name: "Tuning", targets: ["Tuning"]),
    .library(name: "Tutorial", targets: ["Tutorial"]),
    .library(name: "VolumeMonitor", targets: ["VolumeMonitor"]),
  ],
  dependencies: [
    .package(
      url: "https://github.com/bradhowes/AUv3Controls",
      from: "0.23.1"
    ),
    .package(
      url: "https://github.com/bradhowes/brh-splitview",
      from: "1.0.5"
    ),
    .package(
      url: "https://github.com/bradhowes/morkandmidi",
      from: "4.0.1"
    ),
    sf2Lib,
    .package(
      url: "https://github.com/pointfreeco/sqlite-data",
      from: "1.0.0"
    ),
    .package(
      url: "https://github.com/apple/swift-algorithms",
      from: "1.2.1"
    ),
    .package(
      url: "https://github.com/pointfreeco/swift-case-paths",
      from: "1.7.2"
    ),
    .package(
      url: "https://github.com/pointfreeco/swift-composable-architecture",
      from: "1.22.3"
    ),
    .package(
      url: "https://github.com/pointfreeco/swift-dependencies",
      from: "1.10.0"
    ),
    .package(
      url: "https://github.com/apple/swift-numerics",
      from: "1.1.0"
    ),
    .package(
      url: "https://github.com/pointfreeco/swift-sharing",
      from: "2.7.4"
    ),
    .package(
      url: "https://github.com/pointfreeco/swift-snapshot-testing",
      from: "1.18.7"
    ),
    .package(
      url: "https://github.com/pointfreeco/swift-tagged",
      from: "0.10.0"
    ),
    .package(
      url: "https://github.com/athankefalas/swift-toasts",
      from: "0.9.2"
    ),
  ],
  targets: [
    .target(
      name: "AppReview",
      dependencies: [
        "FeatureSupport",
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture")
      ]
    ),
    .target(
      name: "BaseSupport",
      dependencies: [
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture")
      ]
    ),
    .target(
      name: "ChangesFeature",
      dependencies: [
        "FeatureSupport",
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture")
      ]
    ),
    .target(
      name: "DelayEffect",
      dependencies: [
        "FeatureSupport",
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture")
      ]
    ),
    .target(
      name: "FeatureSupport",
      dependencies: [
        "BaseSupport",
        "Models",
        .product(name: "AUv3Controls", package: "AUv3Controls"),
        .product(name: "CasePaths", package: "swift-case-paths"),
        .product(name: "MorkAndMIDI", package: "morkandmidi"),
        .product(name: "Sharing", package: "swift-sharing")
      ]
    ),
    .target(
      name: "Keyboard",
      dependencies: [
        "FeatureSupport",
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
        .product(name: "Algorithms", package: "swift-algorithms")
      ]
    ),
    .target(
      name: "Models",
      dependencies: [
        "SF2Resources",
        "BaseSupport",
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
        .product(name: "SQLiteData", package: "sqlite-data"),
        .product(name: "Tagged", package: "swift-tagged")
      ]
    ),
    .target(
      name: "ReverbEffect",
      dependencies: [
        "FeatureSupport",
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture")
      ]
    ),
    .target(
      name: "SF2Resources",
      dependencies: [
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
        .product(name: "Engine", package: "SF2Lib"),
      ],
      resources: [.process("Resources")]
    ),
    .target(
      name: "Tuning",
      dependencies: [
        "FeatureSupport",
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
      ],
    ),
    .target(
      name: "Tutorial",
      dependencies: [
        "FeatureSupport",
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
      ],
      resources: [.process("Resources")]
    ),
    .target(
      name: "VolumeMonitor",
      dependencies: [
        "FeatureSupport",
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
        .product(name: "SwiftToasts", package: "swift-toasts")
      ]
    ),
    // MARK: - Test Targets
    .testTarget(
      name: "AppReviewTests",
      dependencies: [
        "AppReview",
        .product(name: "DependenciesTestSupport", package: "swift-dependencies"),
        .product(name: "SnapshotTesting", package: "swift-snapshot-testing")
      ]
    ),
    .testTarget(
      name: "BaseSupportTests",
      dependencies: [
        "BaseSupport",
        .product(name: "DependenciesTestSupport", package: "swift-dependencies")
      ]
    ),
    .testTarget(
      name: "ChangesFeatureTests",
      dependencies: [
        "ChangesFeature",
        .product(name: "DependenciesTestSupport", package: "swift-dependencies"),
        .product(name: "SnapshotTesting", package: "swift-snapshot-testing")
      ]
    ),
    .testTarget(
      name: "DelayEffectTests",
      dependencies: [
        "DelayEffect",
        .product(name: "DependenciesTestSupport", package: "swift-dependencies"),
        .product(name: "Numerics", package: "swift-numerics"),
        .product(name: "SnapshotTesting", package: "swift-snapshot-testing")
      ]
    ),
    .testTarget(
      name: "FeatureSupportTests",
      dependencies: [
        "FeatureSupport",
        .product(name: "DependenciesTestSupport", package: "swift-dependencies"),
        .product(name: "Numerics", package: "swift-numerics"),
        .product(name: "SnapshotTesting", package: "swift-snapshot-testing")
      ]
    ),
    .testTarget(
      name: "KeyboardTests",
      dependencies: [
        "Keyboard",
        .product(name: "DependenciesTestSupport", package: "swift-dependencies"),
        .product(name: "SnapshotTesting", package: "swift-snapshot-testing")
      ]
    ),
    .testTarget(
      name: "ModelsTests",
      dependencies: [
        "Models",
        .product(name: "DependenciesTestSupport", package: "swift-dependencies"),
        .product(name: "SnapshotTesting", package: "swift-snapshot-testing")
      ]
    ),
    .testTarget(
      name: "ReverbEffectTests",
      dependencies: [
        "ReverbEffect",
        .product(name: "DependenciesTestSupport", package: "swift-dependencies"),
        .product(name: "Numerics", package: "swift-numerics"),
        .product(name: "SnapshotTesting", package: "swift-snapshot-testing")
      ]
    ),
    .testTarget(
      name: "SF2ResourcesTests",
      dependencies: [
        "SF2Resources",
        .product(name: "DependenciesTestSupport", package: "swift-dependencies"),
        .product(name: "SnapshotTesting", package: "swift-snapshot-testing")
      ]
    ),
    .testTarget(
      name: "TuningTests",
      dependencies: [
        "Tuning",
        .product(name: "DependenciesTestSupport", package: "swift-dependencies"),
        .product(name: "SnapshotTesting", package: "swift-snapshot-testing")
      ]
    ),
    .testTarget(
      name: "TutorialTests",
      dependencies: [
        "Tutorial",
        .product(name: "DependenciesTestSupport", package: "swift-dependencies"),
        .product(name: "SnapshotTesting", package: "swift-snapshot-testing")
      ]
    ),
    .testTarget(
      name: "VolumeMonitorTests",
      dependencies: [
        "VolumeMonitor",
        .product(name: "DependenciesTestSupport", package: "swift-dependencies"),
        .product(name: "SnapshotTesting", package: "swift-snapshot-testing")
      ]
    ),
  ],
  cxxLanguageStandard: .cxx2b
)

// The SF2Lib Engine product requires this for everything it touches, so just do every target.
for target in package.targets {
  var settings = globalSwiftSettings + (target.swiftSettings ?? [])
  if alwaysShowChanges {
    settings.append(.define("ALWAYS_SHOW_CHANGES"))
  }
  if alwaysShowTutorial {
    settings.append(.define("ALWAYS_SHOW_TUTORIAL"))
  }
  target.swiftSettings = settings
}
