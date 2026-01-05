// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import Foundation
import PackageDescription

let useLocalMorkAndMIDI = false
let useLocalSF2Lib = false

let package = Package(
  name: "Features",
  platforms: [.iOS(.v18), .macOS(.v15)],
  products: [
    .lib("AppReview"),
    .lib("AppRoot"),
    .lib("AUv3Root"),
    .lib("BaseSupport"),
    .lib("Changes"),
    .lib("DelayEffect"),
    .lib("FeatureSupport"),
    .lib("FileImporter"),
    .lib("Keyboard"),
    .lib("MIDIAssignments"),
    .lib("MIDIConnections"),
    .lib("MIDIControllers"),
    .lib("MIDITrafficIndicator"),
    .lib("Models"),
    .lib("Presets"),
    .lib("ReverbEffect"),
    .lib("Settings"),
    .lib("SF2LibAU"),
    .lib("SF2Resources"),
    .lib("SoundFonts"),
    .lib("Synth"),
    .lib("Tags"),
    .lib("ToolBar"),
    .lib("Tuning"),
    .lib("Tutorial"),
    .lib("VolumeMonitor"),
  ],

  dependencies: [
    .package(url: "https://github.com/bradhowes/AUv3Controls", from: "0.23.1"),
    .package(url: "https://github.com/bradhowes/brh-splitview", from: "1.0.5"),
    .morkAndMIDI,
    .sf2Lib,
    //
    .package(url: "https://github.com/apple/swift-algorithms", from: "1.2.1"),
    // NOTE: only used to gain access to `isApproximatelyEqual` in unit tests
    .package(url: "https://github.com/apple/swift-numerics", from: "1.1.0"),
    .package(url: "https://github.com/athankefalas/swift-toasts", from: "0.9.2"),
    .package(url: "https://github.com/relatedcode/ProgressHUD", from: "15.0.1"),
    //
    .package(url: "https://github.com/pointfreeco/sqlite-data", from: "1.0.0"),
    .package(url: "https://github.com/pointfreeco/swift-case-paths", from: "1.7.2"),
    .package(url: "https://github.com/pointfreeco/swift-composable-architecture", from: "1.22.3"),
    .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "1.10.0"),
    .package(url: "https://github.com/pointfreeco/swift-sharing", from: "2.7.4"),
    .package(url: "https://github.com/pointfreeco/swift-snapshot-testing", from: "1.18.7"),
    .package(url: "https://github.com/pointfreeco/swift-tagged", from: "0.10.0"),
  ],

  targets: [
    .executableTarget(name: "BuildFluidFontCmd"),
    .plugin(name: "BuildFluidFont", capability: .buildTool, dependencies: ["BuildFluidFontCmd"]),

    // MARK: Feature Targets - features have "FeatureSupport" as a dependency

    .feature("AppReview"),
    .feature(
      "AppRoot",
      dependencies: [
        "AppReview",
        "Changes",
        "DelayEffect",
        "Keyboard",
        "Presets",
        "ReverbEffect",
        "Settings",
        "SoundFonts",
        "Synth",
        "Tags",
        "ToolBar",
        "Tutorial",
        "VolumeMonitor",
        .product(name: "BRHSplitView", package: "brh-splitview"),
        .product(name: "ProgressHUD", package: "ProgressHUD"),
      ]
    ),
    .feature(
      "AUv3Root",
      dependencies: [
        "Presets",
        "Settings",
        "SoundFonts",
        "Tags",
        "ToolBar",
        .product(name: "BRHSplitView", package: "brh-splitview"),
      ]
    ),
    .feature("Changes"),
    .feature("DelayEffect"),
    .feature("FileImporter"),
    .feature("Keyboard"),
    .feature("MIDIAssignments"),
    .feature("MIDIConnections", dependencies: ["MIDITrafficIndicator"]),
    .feature("MIDIControllers"),
    .feature("MIDITrafficIndicator"),
    .feature("Presets", dependencies: ["Tuning"]),
    .feature("ReverbEffect"),
    .feature(
      "Settings",
      dependencies: [
        "Keyboard",
        "FileImporter",
        "MIDIAssignments",
        "MIDIConnections",
        "MIDIControllers",
        "MIDITrafficIndicator",
        "Tuning",
      ]
    ),
    .feature("SoundFonts", dependencies: ["Tags"]),
    .feature("Tags"),
    .feature(
      "ToolBar",
      dependencies: [
        "FileImporter",
        "Keyboard", // Only for preview
        "MIDITrafficIndicator",
        "Settings"
      ],
    ),
    .feature("Tuning"),
    .feature("Tutorial", resources: [.process("Resources")]),
    .feature(
      "VolumeMonitor",
      dependencies: [
        .product(name: "SwiftToasts", package: "swift-toasts")
      ]
    ),

    // MARK: Library Targets

    .target(
        name: "BaseSupport",
        dependencies: [
          "SF2Resources",
          .product(name: "Engine", package: "SF2Lib"),
          .product(name: "Numerics", package: "swift-numerics"),
          .product(name: "SQLiteData", package: "sqlite-data"),
        ]
      ),
    .target(
      name: "FeatureSupport",
      dependencies: [
        "BaseSupport",
        "Models",
        "Synth",
        .product(name: "AUv3Controls", package: "AUv3Controls"),
        .product(name: "CasePaths", package: "swift-case-paths"),
        .product(name: "MorkAndMIDI", package: "morkandmidi"),
        .product(name: "Sharing", package: "swift-sharing")
      ]
    ),
    .target(
      name: "Models",
      dependencies: [
        "BaseSupport",
        "SF2Resources",
        .product(name: "Tagged", package: "swift-tagged")
      ]
    ),
    .target(
      name: "SF2LibAU",
      dependencies: [
        "BaseSupport",
        .product(name: "Engine", package: "SF2Lib")
      ]
    ),
    .target(
      name: "SF2Resources",
      dependencies: [
        .product(name: "Engine", package: "SF2Lib"),
      ],
      resources: [.process("Resources")],
      plugins: ["BuildFluidFont"]
    ),
    .target(
      name: "Synth",
      dependencies: [
        "Models",
        "SF2LibAU",
        .product(name: "AUv3Controls", package: "AUv3Controls")
      ]
    ),

    // Library only used for tests
    .target(
      name: "TestSupport",
      dependencies: [
        "BaseSupport",
        "Models",
        .product(name: "SnapshotTesting", package: "swift-snapshot-testing")
      ]
    ),

    // MARK: - Feature Test Targets - name is the feature name from above, and the test name will be that + "Tests"

    .testFeature("AppReview"),
    .testFeature("AppRoot"),
    .testFeature("AUv3Root"),
    .testFeature("Changes"),
    .testFeature("DelayEffect"),
    .testFeature("FileImporter"),
    .testFeature("Keyboard"),
    .testFeature("MIDIAssignments"),
    .testFeature("MIDIConnections"),
    .testFeature("MIDIControllers"),
    .testFeature("Models"),
    .testFeature("Presets"),
    .testFeature("ReverbEffect"),
    .testFeature("Settings"),
    .testFeature("SoundFonts"),
    .testFeature("Tags"),
    .testFeature("ToolBar"),
    .testFeature("Tuning"),
    .testFeature("Tutorial"),
    .testFeature("VolumeMonitor"),

    // MARK: Library Test Targets

    .testTarget(name: "BaseSupportTests", dependencies: ["BaseSupport"]),
    .testTarget(name: "FeatureSupportTests", dependencies: ["FeatureSupport"]),
    .testTarget(name: "MIDITrafficIndicatorTests", dependencies: ["MIDITrafficIndicator"]),
    .testTarget(name: "SF2ResourcesTests", dependencies: ["BaseSupport"]),
    .testTarget(
      name: "SynthTests",
      dependencies: [
        "BaseSupport",
        "DelayEffect",
        "ReverbEffect",
        "Synth"
      ]
    ),
  ],
  cxxLanguageStandard: .cxx2b
)

setSwiftSettings()

extension Package.Dependency {
  static var sf2Lib: PackageDescription.Package.Dependency {
    useLocalSF2Lib ? .package(
      name: "SF2Lib",
      path: "/Users/howes/src/Mine/SF2Lib"
    ) : .package(
      url: "https://github.com/bradhowes/SF2Lib",
      from: "8.4.0"
    )
  }
}

extension Package.Dependency {
  static var morkAndMIDI: PackageDescription.Package.Dependency {
    useLocalMorkAndMIDI ? .package(
      name: "MorkAndMIDI",
      path: "/Users/howes/src/Mine/morkandmidi"
    ) : .package(
      url: "https://github.com/bradhowes/morkandmidi",
      from: "4.0.2"
    )
  }
}

extension PackageDescription.Product {

  public static func lib(_ name: String) -> PackageDescription.Product {
    .library(name: name, targets: [name])
  }
}

extension PackageDescription.Target {

  public static func feature(
    _ name: String,
    dependencies: [PackageDescription.Target.Dependency] = [],
    resources: [PackageDescription.Resource] = []
  ) -> PackageDescription.Target {
    .target(name: name, dependencies: dependencies + ["FeatureSupport"], resources: resources)
  }

  public static func testFeature(
    _ name: String,
    dependencies: [PackageDescription.Target.Dependency] = [
      .product(name: "Numerics", package: "swift-numerics")
    ],
    resources: [PackageDescription.Resource] = []
  ) -> PackageDescription.Target {
    .testTarget(name: name + "Tests", dependencies: dependencies + [.init(stringLiteral: name)], resources: resources)
  }
}

@MainActor
func setSwiftSettings() {

  let globalSwiftSettings: [SwiftSetting] = [
    .enableExperimentalFeature("StrictConcurrency"),
    .interoperabilityMode(.Cxx),
    .strictMemorySafety(),
    .swiftLanguageMode(.v6)
  ]

  for target in package.targets {
    switch target.type {
      // normal targets
    case .regular:
      let settings = globalSwiftSettings + (target.swiftSettings ?? [])
      target.swiftSettings = settings
      target.dependencies += [
        .product(name: "Algorithms", package: "swift-algorithms"),
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture")
      ]

      // test targets
    case .test:
      target.swiftSettings = globalSwiftSettings + (target.swiftSettings ?? [])
      target.dependencies += [
        "TestSupport",
        .product(name: "DependenciesTestSupport", package: "swift-dependencies"),
        .product(name: "SnapshotTesting", package: "swift-snapshot-testing")
      ]

    default:
      continue
    }
  }
}
