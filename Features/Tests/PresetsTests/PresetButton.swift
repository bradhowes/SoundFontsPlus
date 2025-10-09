import ComposableArchitecture
import CustomSnapshot
import Models
import Sharing
import SnapshotTesting
import SwiftUI
import Testing

@testable import Presets

@Suite(
  .dependencies {
    $0.defaultDatabase = try appDatabase()
  },
  //  .snapshots(record: .failed)
)
@MainActor
struct PresetButtonTests {

  @MainActor
  func setup() throws -> ([Preset], TestStoreOf<PresetButton>) {
    @Shared(.activeState) var activeState
    $activeState.withLock {
      $0.activeSoundFontId = 1
      $0.activePresetId = 1
    }
    let presets = Operations.presets(for: 1)
    let store = TestStore(initialState: PresetButton.State(preset: presets[0])) {
      PresetButton()
    }
    return (presets, store)
  }

  @Test func buttonTapped() async throws {
    let (_, store) = try setup()
    await store.send(\.buttonTapped)
    await store.receive(.delegate(.selectPreset(store.state.preset)))
  }

  @Test func editButtonTapped() async throws {
    let (_, store) = try setup()
    await store.send(\.editButtonTapped)
    await store.receive(.delegate(.editPreset(store.state.preset)))
  }

  @Test func favoriteButtonTapped() async throws {
    let (_, store) = try setup()
    await store.send(\.favoriteButtonTapped)
    await store.receive(.delegate(.createFavorite(store.state.preset)))
  }

  @Test func hidePresetButtonTapped() async throws {
    let (_, store) = try setup()
    await store.send(\.hidePresetButtonTapped)
    await store.receive(.delegate(.hidePreset(store.state.preset)))
  }

  @Test func deleteFavoriteButtonTapped() async throws {
    let (_, store) = try setup()
    await store.send(\.deleteFavoriteButtonTapped)
    await store.receive(.delegate(.deleteFavorite(store.state.preset)))
  }

  @Test func longPressGestureFired() async throws {
    let (_, store) = try setup()
    await store.send(\.longPressGestureFired)
    await store.receive(.delegate(.editPreset(store.state.preset)))
  }

  @Test func toggleVisibility() async throws {
    let (_, store) = try setup()
    await store.send(\.toggleVisibility) {
      $0.preset.kind = .hidden
    }
  }

  @Test func presetButtonPreview() async throws {
    try withSnapshotTesting(record: .failed) {
      try CustomSnapshot.assertSnapshot(matching: PresetButtonView.preview)
    }
  }
}
