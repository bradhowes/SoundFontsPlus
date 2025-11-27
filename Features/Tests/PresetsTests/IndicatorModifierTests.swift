// Copyright © 2025 Brad Howes. All rights reserved.

import DependenciesTestSupport
import FeatureSupport
import SnapshotTesting
import Testing
import TestSupport

@testable import Presets

@Suite(
  .dependency(\.defaultDatabase, TestSupport.testDatabase(seeder: TestSupport.addMockPresets)),
  .snapshots(record: .failed)
)
@MainActor
struct IndicatorModifierTests {

  @Test
  func renderingNormalSelected() async throws {
    var presets = Operations.presets(for: nil)
    if let clone = presets.last!.clone() {
      presets.append(clone)
    }

    let view = VStack {
      List {
        PresetButtonView(store: Store(initialState: PresetButton.State(preset: presets[0])) { PresetButton() })
        PresetButtonView(store: Store(initialState: PresetButton.State.init(preset: presets[1])) { PresetButton() })
        PresetButtonView(store: Store(initialState: PresetButton.State.init(preset: presets.last!)) { PresetButton() })
        Text("ActiveNoIndicator")
          .indicator(.activeNoIndicator)
      }
      .listStyle(.plain)
      .environment(\.editMode, .constant(.inactive))
      .tint(.teal)
    }

    try TestSupport.assertSnapshot(matching: view)
  }

  @Test
  func renderingFavoriteSelected() async throws {
    var presets = Operations.presets(for: nil)
    if let clone = presets.last!.clone() {
      presets.append(clone)
    }

    @Shared(.activeState) var activeState
    $activeState.activePresetId.withLock { $0 = presets.last?.id }

    let view = VStack {
      List {
        PresetButtonView(store: Store(initialState: PresetButton.State(preset: presets[0])) { PresetButton() })
        PresetButtonView(store: Store(initialState: PresetButton.State.init(preset: presets[1])) { PresetButton() })
        PresetButtonView(store: Store(initialState: PresetButton.State.init(preset: presets.last!)) { PresetButton() })
        Text("Selected")
          .indicator(.selected)
      }
      .listStyle(.plain)
      .environment(\.editMode, .constant(.inactive))
      .tint(.teal)
    }

    try TestSupport.assertSnapshot(matching: view)
  }

  @Test
  func renderingNormalSelectedEditing() async throws {
    var presets = Operations.presets(for: nil)
    if let clone = presets.last!.clone() {
      presets.append(clone)
    }

    let view = VStack {
      List {
        PresetButtonView(store: Store(initialState: PresetButton.State(preset: presets[0])) { PresetButton() })
        PresetButtonView(store: Store(initialState: PresetButton.State.init(preset: presets[1])) { PresetButton() })
        PresetButtonView(store: Store(initialState: PresetButton.State.init(preset: presets.last!)) { PresetButton() })
        Text("ActiveNoIndicator")
          .indicator(.activeNoIndicator)
      }
      .listStyle(.plain)
      .environment(\.editMode, .constant(.active))
      .tint(.teal)
    }

    try TestSupport.assertSnapshot(matching: view)
  }

  @Test
  func renderingFavoriteSelectedEditing() async throws {
    var presets = Operations.presets(for: nil)
    if let clone = presets.last!.clone() {
      presets.append(clone)
    }

    @Shared(.activeState) var activeState
    $activeState.activePresetId.withLock { $0 = presets.last?.id }

    let view = VStack {
      List {
        PresetButtonView(store: Store(initialState: PresetButton.State(preset: presets[0])) { PresetButton() })
        PresetButtonView(store: Store(initialState: PresetButton.State.init(preset: presets[1])) { PresetButton() })
        PresetButtonView(store: Store(initialState: PresetButton.State.init(preset: presets.last!)) { PresetButton() })
        Text("Selected")
          .indicator(.selected)
        Text("True")
          .indicator(true)
        Text("False")
          .indicator(false)
      }
      .listStyle(.plain)
      .environment(\.editMode, .constant(.active))
      .tint(.teal)
    }

    try TestSupport.assertSnapshot(matching: view)
  }
}
