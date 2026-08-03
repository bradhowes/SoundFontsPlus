// Copyright © 2025 Brad Howes. All rights reserved.

import DependenciesTestSupport
import FeatureSupport
import SnapshotTesting
import SQLiteData
import Tagged
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
    let presets = PresetInfo.visible(for: 1)
    let store = TestStore(
      initialState: .init(
        id: 4,
        title: "Blah",
        indexKey: "B",
        presets: presets[...]
      )
    ) {
      PresetsListSection()
    }
    return store
  }
}
