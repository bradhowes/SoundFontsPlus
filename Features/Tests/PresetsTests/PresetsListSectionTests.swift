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
    @Shared(.activeState) var activeState
    $activeState.withLock {
      $0.activeSoundFontId = 1
      $0.activePresetId = 1
    }

    let presets = Operations.presets(for: 1)
    let store = TestStore(initialState: PresetsListSection.State(section: 40, presets: presets[...])) {
      PresetsListSection()
    }
    return store
  }
}
