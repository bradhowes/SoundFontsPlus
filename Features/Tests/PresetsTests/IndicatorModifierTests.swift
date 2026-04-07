// Copyright © 2025 Brad Howes. All rights reserved.

import DependenciesTestSupport
import FeatureSupport
import SnapshotTesting
import Testing
import TestSupport

@testable import Presets

@Suite(
  .dependencies {
    $0.defaultDatabase = TestSupport.testDatabase(seeder: TestSupport.addMockPresets)
  },
  .snapshots(record: .failed)
)
@MainActor
struct IndicatorModifierTests {

  @Shared(.showOnlyFavorites) var showOnlyFavorites = false

  init() {
    $showOnlyFavorites.withLock { $0 = false }
  }

  @Test
  func renderingNormalSelected() async throws {
    withDependencies {
      $0.defaultDatabase = previewDatabase()
    } operation: {
      withSnapshotTesting(record: .failed) {
        var presets = Preset.visible(for: 1)
        if let clone = presets.last!.clone() {
          presets.append(clone)
        }

        let view = VStack {
          List {
            PresetButtonView(store: Store(initialState: PresetButton.State(preset: presets[0], symbolPrefix: "star.circle.fill")) {
              PresetButton()
            }, indicatorModifierState: .active)
            PresetButtonView(store: Store(initialState: PresetButton.State.init(preset: presets[1], symbolPrefix: "star.circle.fill")) {
              PresetButton()
            }, indicatorModifierState: .none)
            PresetButtonView(store: Store(initialState: PresetButton.State.init(preset: presets.last!, symbolPrefix: "star.circle.fill")) {
              PresetButton()
            }, indicatorModifierState: .none)
            Text("ActiveNoIndicator")
              .indicator(.activeNoIndicator)
          }
          .listStyle(.plain)
          // .environment(\.editMode, .constant(.inactive))
          .tint(.teal)
        }
        TestSupport.assertSnapshot(matching: view)
      }
    }
  }

  @Test
  func renderingFavoriteSelected() async throws {
    withDependencies {
      $0.defaultDatabase = previewDatabase()
    } operation: {
      withSnapshotTesting(record: .failed) {
        var presets = Preset.visible(for: 1)
        if let clone = presets.last!.clone() {
          presets.append(clone)
        }

        let view = VStack {
          List {
            PresetButtonView(store: Store(initialState: PresetButton.State(preset: presets[0], symbolPrefix: "star.circle.fill")) {
              PresetButton()
            }, indicatorModifierState: .none)
            PresetButtonView(store: Store(initialState: PresetButton.State.init(preset: presets[1], symbolPrefix: "star.circle.fill")) {
              PresetButton()
            }, indicatorModifierState: .none)
            PresetButtonView(store: Store(initialState: PresetButton.State.init(preset: presets.last!, symbolPrefix: "star.circle.fill")) {
              PresetButton()
            }, indicatorModifierState: .none)
            Text("Selected")
              .indicator(.selected)
          }
          .listStyle(.plain)
          // .environment(\.editMode, .constant(.inactive))
          .tint(.teal)
        }
        TestSupport.assertSnapshot(matching: view)
      }
    }
  }

#if os(iOS)
  @Test
  func renderingNormalSelectedEditing() async throws {
    withDependencies {
      $0.defaultDatabase = previewDatabase()
    } operation: {
      withSnapshotTesting(record: .failed) {
        var presets = Preset.visible(for: 1)
        if let clone = presets.last!.clone() {
          presets.append(clone)
        }

        let view = VStack {
          List {
            PresetButtonView(store: Store(initialState: PresetButton.State(preset: presets[0], symbolPrefix: "star.circle.fill")) {
              PresetButton()
            }, indicatorModifierState: .none)
            PresetButtonView(store: Store(initialState: PresetButton.State.init(preset: presets[1], symbolPrefix: "star.circle.fill")) {
              PresetButton()
            }, indicatorModifierState: .none)
            PresetButtonView(store: Store(initialState: PresetButton.State.init(preset: presets.last!, symbolPrefix: "star.circle.fill")) {
              PresetButton()
            }, indicatorModifierState: .none)
            Text("ActiveNoIndicator")
              .indicator(.activeNoIndicator)
          }
          .listStyle(.plain)
          .environment(\.editMode, .constant(.active))
          .tint(.teal)
        }
        TestSupport.assertSnapshot(matching: view)
      }
    }
  }

  @Test
  func renderingFavoriteSelectedEditing() async throws {
    withDependencies {
      $0.defaultDatabase = previewDatabase()
    } operation: {
      withSnapshotTesting(record: .failed) {
        var presets = Preset.visible(for: 1)
        if let clone = presets.last!.clone() {
          presets.append(clone)
        }

        let view = VStack {
          List {
            PresetButtonView(store: Store(initialState: PresetButton.State(preset: presets[0], symbolPrefix: "star.circle.fill")) {
              PresetButton()
            }, indicatorModifierState: .active)
            PresetButtonView(store: Store(initialState: PresetButton.State.init(preset: presets[1], symbolPrefix: "star.circle.fill")) {
              PresetButton()
            }, indicatorModifierState: .none)
            PresetButtonView(store: Store(initialState: PresetButton.State.init(preset: presets.last!, symbolPrefix: "star.circle.fill")) {
              PresetButton()
            }, indicatorModifierState: .none)
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
        TestSupport.assertSnapshot(matching: view)
      }
    }
  }
#endif // os(iOS)
}
