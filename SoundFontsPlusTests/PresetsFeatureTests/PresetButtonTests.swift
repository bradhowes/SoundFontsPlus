import ComposableArchitecture
import Sharing
import SnapshotTesting
import SwiftUI
import Testing

@testable import SoundFontsPlus

extension BaseTestSuite {

  @MainActor
  struct PresetButtonTests {}
}

extension BaseTestSuite.PresetButtonTests {

  @MainActor
  func setup() throws -> ([Preset], TestStoreOf<PresetButton>) {
    @Shared(.activeState) var activeState
    $activeState.withLock {
      $0.activeSoundFontId = 1
      $0.activePresetId = 1
    }
    let presets = Operations.presets
    let store = TestStore(initialState: PresetButton.State(preset: presets[0])) {
      PresetButton()
    }
    return (presets, store)
  }

  @Test func testButtonTapped() async throws {
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

  @Test func testHideButtonTapped() async throws {
    let (_, store) = try setup()
    await store.send(\.hideOrDeleteButtonTapped)
    await store.receive(.delegate(.hideOrDeletePreset(store.state.preset)))
  }

//
//  @Test func testHideButtonTappedNoPrompt() async throws {
//    try await initialize { store in
//      @Shared(.stopConfirmingPresetHiding) var stopConfirmingPresetHiding
//      $stopConfirmingPresetHiding.withLock { $0 = true }
//
//      await store.send(\.hideButtonTapped)
//      await store.receive(.delegate(.hidePreset(store.state.preset)))
//    }
//  }
//
//  func fetchPreset(presetId: Preset.ID) async throws -> Preset {
//    @Dependency(\.defaultDatabase) var database
//    let preset = try await database.read { try Preset.fetchOne($0, id: presetId) }
//    guard let preset else {
//      Issue.record("Failed to fetch existing preset")
//      fatalError()
//    }
//    return preset
//  }
//
//  @Test func testToggleVisibility() async throws {
//    try await initialize { store in
//
//      #expect(store.state.preset.visible == true)
//      await store.send(\.toggleVisibility) { $0.preset.visible = false }
//
//      var preset = try await fetchPreset(presetId: store.state.id)
//      #expect(preset.visible == false)
//
//      await store.send(\.toggleVisibility) { $0.preset.visible = true }
//      preset = try await fetchPreset(presetId: store.state.id)
//      #expect(preset.visible == true)
//    }
//  }
//
  @Test func presetButtonPreview() async throws {
    struct HostView: SwiftUI.View {
      var body: some SwiftUI.View {
        PresetButtonView.preview
          .environment(\.editMode, .constant(.inactive))
      }
    }
    let view = HostView()
    try withSnapshotTesting(record: .failed) {
      try BaseTestSuite.assertSnap(
        matching: view,
        size: .init(width: 400, height: 800),
        colorScheme: .dark
      )
    }
  }
}
