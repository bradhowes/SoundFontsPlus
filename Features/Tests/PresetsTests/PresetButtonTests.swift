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
    @Shared(.activeState) var activeState = .default
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
    return TestStore(initialState: PresetButton.State(preset: preset, editingVisibility: false)) {
      PresetButton()
    }
  }

  @Test(
    .dependencies { $0.defaultDatabase = TestSupport.testDatabase(seeder: TestSupport.addMockPresets) }
  )
  func toggleVisibility() async throws {
    let store = store()
    await store.send(\.toggleVisibility) {
      $0.preset.kind = .hidden
    }
  }

  @Test
  func presetButtonPreview() async throws {
    try TestSupport.assertSnapshot(matching: PresetButtonView.preview)
  }
}
