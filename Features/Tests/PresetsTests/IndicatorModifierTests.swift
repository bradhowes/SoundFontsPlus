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

  func seedFavorite() {
    var presets = Preset.all(for: 1)
    if let clone = presets.last!.cloneFavorite() {
      presets.append(clone)
    }
  }

  @Test
  func renderingNormalSelected() async throws {
    withDependencies {
      $0.defaultDatabase = previewDatabase()
    } operation: {
      withSnapshotTesting(record: .failed) {
        seedFavorite()
        let presets = PresetInfo.visible(for: 1)
        let view = VStack {
          List {
            PresetButtonView(
              store: Store(
                initialState: PresetButton.State(
                  id: presets[0].id,
                  displayName: presets[0].displayName,
                  kind: presets[0].kind,
                  symbolPrefix: "star.circle.fill"
                )
              ) {
                PresetButton()
              },
              indicatorModifierState: .active
            )
            PresetButtonView(
              store: Store(
                initialState: PresetButton.State.init(
                  id: presets[1].id,
                  displayName: presets[1].displayName,
                  kind: presets[1].kind,
                  symbolPrefix: "star.circle.fill"
                )
              ) {
                PresetButton()
              },
              indicatorModifierState: .none
            )
            PresetButtonView(
              store: Store(
                initialState: PresetButton.State.init(
                  id: presets.last!.id,
                  displayName: presets.last!.displayName,
                  kind: presets.last!.kind,
                  symbolPrefix: "star.circle.fill"
                )
              ) {
                PresetButton()
              },
              indicatorModifierState: .none
            )
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
        seedFavorite()
        let presets = PresetInfo.visible(for: 1)
        let view = VStack {
          List {
            PresetButtonView(
              store: Store(
                initialState: PresetButton.State(
                  id: presets[0].id,
                  displayName: presets[0].displayName,
                  kind: presets[0].kind,
                  symbolPrefix: "star.circle.fill"
                )
              ) {
                PresetButton()
              },
              indicatorModifierState: .none)
            PresetButtonView(
              store: Store(
                initialState: PresetButton.State.init(
                  id: presets[1].id,
                  displayName: presets[1].displayName,
                  kind: presets[1].kind,
                  symbolPrefix: "star.circle.fill"
                )
              ) {
                PresetButton()
              },
              indicatorModifierState: .none)
            PresetButtonView(
              store: Store(
                initialState: PresetButton.State.init(
                  id: presets.last!.id,
                  displayName: presets.last!.displayName,
                  kind: presets.last!.kind,
                  symbolPrefix: "star.circle.fill"
                )
              ) {
                PresetButton()
              },
              indicatorModifierState: .none)
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
        seedFavorite()
        let presets = PresetInfo.visible(for: 1)

        let view = VStack {
          List {
            PresetButtonView(
              store: Store(
                initialState: PresetButton.State(
                  id: presets[0].id,
                  displayName: presets[0].displayName,
                  kind: presets[0].kind,
                  symbolPrefix: "star.circle.fill"
                )
              ) {
                PresetButton()
              },
              indicatorModifierState: .none)
            PresetButtonView(
              store: Store(
                initialState: PresetButton.State.init(
                  id: presets[1].id,
                  displayName: presets[1].displayName,
                  kind: presets[1].kind,
                  symbolPrefix: "star.circle.fill"
                )
              ) {
                PresetButton()
              },
              indicatorModifierState: .none)
            PresetButtonView(
              store: Store(
                initialState: PresetButton.State.init(
                  id: presets.last!.id,
                  displayName: presets.last!.displayName,
                  kind: presets.last!.kind,
                  symbolPrefix: "star.circle.fill"
                )
              ) {
                PresetButton()
              },
              indicatorModifierState: .none)
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
        seedFavorite()
        let presets = PresetInfo.visible(for: 1)

        let view = VStack {
          List {
            PresetButtonView(
              store: Store(
                initialState: PresetButton.State(
                  id: presets[0].id,
                  displayName: presets[0].displayName,
                  kind: presets[0].kind,
                  symbolPrefix: "star.circle.fill"
                )
              ) {
                PresetButton()
              },
              indicatorModifierState: .active)
            PresetButtonView(
              store: Store(
                initialState: PresetButton.State.init(
                  id: presets[1].id,
                  displayName: presets[1].displayName,
                  kind: presets[1].kind,
                  symbolPrefix: "star.circle.fill"
                )
              ) {
                PresetButton()
              },
              indicatorModifierState: .none)
            PresetButtonView(
              store: Store(
                initialState: PresetButton.State.init(
                  id: presets.last!.id,
                  displayName: presets.last!.displayName,
                  kind: presets.last!.kind,
                  symbolPrefix: "star.circle.fill"
                )
              ) {
                PresetButton()
              },
              indicatorModifierState: .none)
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
