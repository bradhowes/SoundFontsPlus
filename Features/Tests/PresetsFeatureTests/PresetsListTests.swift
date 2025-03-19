import Testing

import ComposableArchitecture
import Dependencies
import GRDB
import Models
import SF2ResourceFiles
import Tagged
@testable import PresetsFeature

@MainActor
struct PresetsListTests {

  func initialize(_ body: (Array<SoundFont>, TestStoreOf<PresetsList>) async throws -> Void) async throws {
    try await TestSupport.initialize { soundFonts, presets in
      @Shared(.activeState) var activeState
      $activeState.withLock {
        $0.selectedSoundFontId = soundFonts[0].id
      }
      try await body(soundFonts, TestStore(initialState: PresetsList.State(soundFont: soundFonts[0])) {
        PresetsList()
      })
    }
  }

  @Test func creationWithNilSoundFont() async throws {
    try await TestSupport.initialize { soundFonts, presets in
      let store = TestStore(initialState: PresetsList.State(soundFont: nil)) { PresetsList() }
      #expect(store.state.sections.count == 0)
      await store.send(.onAppear)
      await store.receive(\.selectedSoundFontIdChanged)
      #expect(store.state.sections.count == 0)
      await store.send(.stop)
      await store.finish()
    }
  }

  @Test func creation() async throws {
    try await initialize { soundFonts, store in
      #expect(store.state.sections.count == 24)
      await store.send(.onAppear)
      await store.receive(\.selectedSoundFontIdChanged)
      #expect(store.state.sections.count == 24)
      await store.send(.stop)
      await store.finish()
    }
  }

  @Test func detectSoundFontIdChange() async throws {
    try await initialize { soundFonts, store in
      await store.send(.onAppear)
      await store.receive(\.selectedSoundFontIdChanged)

      @Shared(.activeState) var activeState
      $activeState.withLock {
        $0.selectedSoundFontId = soundFonts[1].id
      }

      await store.receive(\.selectedSoundFontIdChanged) {
        $0.soundFont = soundFonts[1]
        $0.sections = PresetsFeature.generatePresetSections(soundFont: soundFonts[1], editing: false)
      }

      await store.send(.stop)
      await store.finish()
    }
  }

  @Test func seesButtonTap() async throws {
    try await initialize { soundFonts, store in
      let preset = soundFonts[0].presets[3]
      await store.send(.sections(.element(id: 0, action: .rows(.element(id: 4, action: .buttonTapped)))))
      await store.receive(.sections(.element(id: 0, action: .rows(.element(id: 4, action: .delegate(.selectPreset(preset)))))))
    }
  }

  @Test func editButtonTapped() async throws {
    try await initialize { soundFonts, store in
      let preset = soundFonts[0].presets[3]
      await store.send(.sections(.element(id: 0, action: .rows(.element(id: 4, action: .editButtonTapped)))))
      await store.receive(.sections(.element(id: 0, action: .rows(.element(id: 4, action: .delegate(.editPreset(preset))))))) {
        $0.destination = .edit(PresetEditor.State(preset: preset))
      }
      await store.send(.destination(.presented(.edit(.acceptButtonTapped))))
      await store.receive(.destination(.dismiss)) {
        $0.destination = nil
      }
    }
  }

  @Test func fetchPresets() async throws {
    try await initialize { soundFonts, store in
      let sections = store.state.sections.count

      @Dependency(\.defaultDatabase) var database
      let presets = soundFonts[0].presets
      for preset in presets[0..<15] {
        try await database.write {
          var preset = preset
          preset.visible = false
          try preset.save($0)
        }
      }

      store.exhaustivity = .off
      await store.send(.fetchPresets)
      #expect(store.state.sections.count < sections)
      await store.send(.toggleEditMode) {
        $0.editingVisibility = true
      }
      #expect(store.state.sections.count == sections)
      await store.send(.toggleEditMode) {
        $0.editingVisibility = false
      }
      #expect(store.state.sections.count < sections)
    }
  }

  @Test func hidePreset() async throws {
    try await initialize { soundFonts, store in
      var preset = soundFonts[0].presets[0]
      #expect(preset.visible == true)

      @Shared(.stopConfirmingPresetHiding) var stopConfirmingPresetHiding
      $stopConfirmingPresetHiding.withLock { $0 = true }
      #expect(store.state.sections[0].rows[0].preset.displayName == "Piano 1")

      await store.send(.sections(.element(id: 0, action: .rows(.element(id: 1, action: .hideButtonTapped)))))
      store.exhaustivity = .off
      await store.receive(.sections(.element(id: 0, action: .rows(.element(id: 1, action: .delegate(.hidePreset(preset)))))))

      preset = try await TestSupport.fetchPreset(presetId: preset.id)
      #expect(preset.visible == false)

      await store.receive(.fetchPresets)
      #expect(store.state.sections[0].rows[0].preset.displayName == "Piano 2")
    }
  }
}
