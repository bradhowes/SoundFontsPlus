// Copyright © 2025 Brad Howes. All rights reserved.

import DependenciesTestSupport
import FeatureSupport
import SnapshotTesting
import Testing
import TestSupport

@testable import Presets

@Suite(
  .dependencies {
    $0.defaultDatabase = TestSupport.testDatabase()
  },
  //  .snapshots(record: .failed)
)
@MainActor
struct PresetsListSectionTests {

  func setup() throws -> TestStoreOf<PresetsListSection> {
    let presets = Preset.visible(for: 1)
    let store = TestStore(
      initialState: PresetsListSection.State(
        section: 40,
        presets: presets[...],
        symbolPrefix: "star.circle.fill"
      )
    ) {
      PresetsListSection()
    }
    return store
  }
}
