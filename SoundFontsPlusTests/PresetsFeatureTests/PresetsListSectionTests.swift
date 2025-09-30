import ComposableArchitecture
import Sharing
import SnapshotTesting
import SwiftUI
import Testing

@testable import SoundFontsPlus

extension BaseTestSuite {

  @MainActor
  struct PresetsListSectionTests {}
}

extension BaseTestSuite.PresetsListSectionTests {

  @MainActor
  func setup() throws -> TestStoreOf<PresetsListSection> {
    @Shared(.activeState) var activeState
    $activeState.withLock {
      $0.activeSoundFontId = 1
      $0.activePresetId = 1
    }

    let presets = Operations.presets
    let store = TestStore(initialState: PresetsListSection.State(section: 40, presets: presets[...])) {
      PresetsListSection()
    }
    return store
  }

  @Test func headerTapped() async throws {
    let store = try setup()

    await store.send(\.headerTapped, 1)
    await store.receive(\.delegate, .headerTapped(Preset.ID(rawValue: 21)))

    await store.send(\.headerTapped, 2)
    await store.receive(\.delegate, .headerTapped(Preset.ID(rawValue: 1)))
  }

  @Test func searchButtonTapped() async throws {
    let store = try setup()

    await store.send(\.searchButtonTapped)
    await store.receive(\.delegate, .searchButtonTapped)
  }
}
