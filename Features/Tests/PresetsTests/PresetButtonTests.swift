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
    return TestStore(initialState: PresetButton.State(preset: preset)) {
      PresetButton()
    }
  }

  @Test func buttonTapped() async throws {
    let store = store()
    await store.send(\.buttonTapped)
    await store.receive(\.delegate, .selectPreset(store.state.preset))
  }

  @Test func editButtonTapped() async throws {
    let store = store()
    await store.send(\.editButtonTapped)
    await store.receive(\.delegate, .editPreset(store.state.preset))
  }

  @Test func favoriteButtonTapped() async throws {
    let store = store()
    await store.send(\.favoriteButtonTapped)
    await store.receive(\.delegate, .createFavorite(store.state.preset))
  }

  @Test func hidePresetButtonTapped() async throws {
    let store = store()
    await store.send(\.hidePresetButtonTapped)
    await store.receive(\.delegate, .hidePreset(store.state.preset))
  }

  @Test func deleteFavoriteButtonTapped() async throws {
    let store = store()
    await store.send(\.deleteFavoriteButtonTapped)
    await store.receive(\.delegate, .deleteFavorite(store.state.preset))
  }

  @Test func longPressGestureFired() async throws {
    let store = store()
    await store.send(\.longPressGestureFired)
    await store.receive(\.delegate, .editPreset(store.state.preset))
  }

  @Test(
    .dependencies { $0.defaultDatabase = try appDatabase() }
  )
  func toggleVisibility() async throws {
    let store = store()
    await store.send(\.toggleVisibility) {
      $0.preset.kind = .hidden
    }
  }

  @Test func presetButtonPreview() async throws {
    try TestSupport.assertSnapshot(matching: PresetButtonView.preview)
  }
}
