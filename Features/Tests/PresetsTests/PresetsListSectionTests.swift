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

  @Test
  func headerTapped() async throws {
    let store = try setup()

    await store.send(\.headerTapped, 1)
    await store.receive(\.delegate.headerTapped, 21)

    await store.send(\.headerTapped, 2)
    await store.receive(\.delegate.headerTapped, 1)
  }

  @Test
  func searchButtonTapped() async throws {
    let store = try setup()

    await store.send(\.searchButtonTapped)
    await store.receive(\.delegate.searchButtonTapped)
  }
}
