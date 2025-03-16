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

  @Test func creation() async throws {
    try await withDependencies {
      $0.defaultDatabase = try DatabaseQueue.appDatabase(addMocks: true)
    } operation: {
      @Dependency(\.defaultDatabase) var database
      let soundFonts = try await database.read { try SoundFont.fetchAll($0) }
      let store = TestStore(initialState: PresetsList.State(soundFont: soundFonts[0])) {
        PresetsList()
      }


      await store.send(.onAppear)
      await store.receive(\.selectedSoundFontIdChanged) {
        $0.soundFont = nil
        $0.sections = []
      }

      await store.send(.stop)
      await store.finish()
    }
  }

  @Test func detectSoundFontIdChange() async throws {
    try await withDependencies {
      $0.defaultDatabase = try DatabaseQueue.appDatabase(addMocks: true)
    } operation: {
      @Dependency(\.defaultDatabase) var database
      let soundFonts = try await database.read { try SoundFont.fetchAll($0) }
      let store = TestStore(initialState: PresetsList.State(soundFont: soundFonts[0])) {
        PresetsList()
      }

      await store.send(.onAppear)
      await store.receive(\.selectedSoundFontIdChanged) {
        $0.soundFont = nil
        $0.sections = []
      }

      @Shared(.activeState) var activeState
      $activeState.withLock {
        $0.selectedSoundFontId = soundFonts[0].id
      }

      await store.receive(\.selectedSoundFontIdChanged) {
        $0.soundFont = soundFonts[0]
        $0.sections = PresetsFeature.generatePresetSections(soundFont: soundFonts[0], editing: false)
      }

      await store.send(.stop)
      await store.finish()
    }
  }
}
