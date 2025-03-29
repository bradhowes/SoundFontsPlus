import Testing

import ComposableArchitecture
import Dependencies
import GRDB
import Models
import SF2ResourceFiles
import SnapshotTesting
import SwiftUI
import Tagged
@testable import SoundFontsFeature

@MainActor
struct SoundFontButtonTests {
  func initialize(_ body: (TestStoreOf<SoundFontButton>) async throws -> Void) async throws {
    try await TestSupport.initialize { soundFonts, presets in
      try await body(TestStore(initialState: SoundFontButton.State(preset: soundFonts[0])) {
        SoundFontButton()
      })
    }
  }

  @Test func testButtonTapped() async throws {
    try await initialize { store in
      await store.send(\.buttonTapped)
      await store.receive(.delegate(.selectSoundFont(store.state.soundFont)))
    }
  }

//  @Test func editButtonTapped() async throws {
//    try await initialize { store in
//      await store.send(\.editButtonTapped)
//      await store.receive(.delegate(.editPreset(store.state.preset)))
//    }
//  }
//
//  @Test func favoriteButtonTapped() async throws {
//    try await initialize { store in
//      await store.send(\.favoriteButtonTapped)
//      await store.receive(.delegate(.createFavorite(store.state.preset)))
//    }
//  }
//
//  @Test func testHideButtonTapped() async throws {
//    try await initialize { store in
//      await store.send(\.hideButtonTapped) {
//        $0.confirmationDialog = PresetButton.hideConfirmationDialogState(displayName: store.state.preset.displayName)
//      }
//      await store.send(\.confirmationDialog.hideButtonTapped) {
//        $0.confirmationDialog = nil
//      }
//      await store.receive(.delegate(.hidePreset(store.state.preset)))
//
//      await store.send(\.hideButtonTapped) {
//        $0.confirmationDialog = PresetButton.hideConfirmationDialogState(displayName: store.state.preset.displayName)
//      }
//      await store.send(\.confirmationDialog.cancelButtonTapped) {
//        $0.confirmationDialog = nil
//      }
//    }
//  }
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
//  @Test func soundFontButtonPreview() async throws {
//    withSnapshotTesting(record: .failed) {
//      struct HostView: SwiftUI.View {
//        var body: some SwiftUI.View {
//          PresetButtonView.preview
//            .environment(\.editMode, .constant(.inactive))
//        }
//      }
//      let view = HostView()
//      assertSnapshot(of: view, as: .image(layout: .device(config: .iPhoneSe), traits: .init(userInterfaceStyle: .dark)))
//    }
//  }
}
