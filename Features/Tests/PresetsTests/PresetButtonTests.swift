// Copyright © 2025 Brad Howes. All rights reserved.

import DependenciesTestSupport
import FeatureSupport
import SnapshotTesting
import Testing
import TestSupport

@testable import Presets

@Suite(
  .snapshots(record: .failed)
)
@MainActor
struct PresetButtonTests {

  func store() -> TestStoreOf<PresetButton> {
    let preset = Preset(
      id: 1,
      index: 1,
      bank: 1,
      program: 2,
      originalName: "Blah",
      soundFontId: 1,
      displayName: "Blah",
      notes: "",
      kind: .preset
    )
    return TestStore(initialState: PresetButton.State(preset: preset, symbolPrefix: "star.circle.fill")) {
      PresetButton()
    }
  }

  @Test(
    .dependencies {
      $0.defaultDatabase = TestSupport.testDatabase(seeder: TestSupport.addMockPresets)
    }
  )
  func toggleVisibility() async throws {
    let store = store()
    await store.send(\.toggleVisibility) {
      $0.preset.kind = .hidden
    }
  }

#if SNAPSHOTS
  @Test
  func presetButtonPreview() async throws {
    withDependencies {
      $0.defaultDatabase = previewDatabase()
    } operation: {
      withSnapshotTesting(record: .failed) {
        TestSupport.assertSnapshot(matching: PresetButtonView.preview)
      }
    }
  }
#endif
}
