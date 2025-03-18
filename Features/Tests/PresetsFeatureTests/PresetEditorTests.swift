import Testing

import ComposableArchitecture
import Dependencies
import GRDB
import Models
import SF2ResourceFiles
import Tagged
@testable import PresetsFeature

@MainActor
struct PresetEditorTests {

  func initialize(_ body: (TestStoreOf<PresetEditor>) async throws -> Void) async throws {
    try await TestSupport.initialize { soundFonts, presets in
      try await body(TestStore(initialState: PresetEditor.State(preset: presets[0])) {
        PresetEditor()
      })
    }
  }

  @Test func acceptButtonTappedSavesChanges() async throws {
    try await initialize { store in
      await store.send(\.binding.displayName, "New Name") {
        $0.displayName = "New Name"
      }
      await store.send(\.binding.notes, "Important notes") {
        $0.notes = "Important notes"
      }
      await store.send(\.binding.visible, false) {
        $0.visible = false
      }
      await store.send(\.acceptButtonTapped) {
        $0.preset.displayName = "New Name"
        $0.preset.notes = "Important notes"
        $0.preset.visible = false
      }

      let preset = try await TestSupport.fetchPreset(presetId: store.state.preset.id)
      #expect(preset.displayName == "New Name")
      #expect(preset.notes == "Important notes")
      #expect(preset.visible == false)
    }
  }

  @Test func cancelButtonTappedIgnoresChanges() async throws {
    try await initialize { store in
      await store.send(\.binding.displayName, "New Name") {
        $0.displayName = "New Name"
      }
      await store.send(\.binding.notes, "Important notes") {
        $0.notes = "Important notes"
      }
      await store.send(\.binding.visible, false) {
        $0.visible = false
      }

      await store.send(\.dismissButtonTapped)

      let preset = try await TestSupport.fetchPreset(presetId: store.state.preset.id)
      #expect(preset == store.state.preset)
    }
  }

  @Test func useOriginalNameButtonTappedResetsNameChanges() async throws {
    try await initialize { store in
      await store.send(\.binding.displayName, "New Name") {
        $0.displayName = "New Name"
      }
      await store.send(\.binding.notes, "Important notes") {
        $0.notes = "Important notes"
      }

      await store.send(\.useOriginalNameTapped) {
        $0.displayName = store.state.preset.displayName
      }
    }
  }
}
