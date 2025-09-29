import ComposableArchitecture
import Sharing
import SnapshotTesting
import SwiftUI
import Testing

@testable import SoundFontsPlus

extension BaseTestSuite {

  @MainActor
  struct PresetEditorTests {}
}

extension BaseTestSuite.PresetEditorTests {

  @MainActor
  func setup() throws -> (Preset, TestStoreOf<PresetEditor>) {
    @Shared(.activeState) var activeState
    $activeState.withLock {
      $0.activeSoundFontId = 1
      $0.activePresetId = 1
    }
    let presets = Operations.presets
    let store = TestStore(initialState: PresetEditor.State(sectionId: 123, preset: presets[0])) {
      PresetEditor()
    }
    return (presets[0], store)
  }

  @Test func acceptButtonTappedSavesChanges() async throws {
    let (preset, store) = try setup()

    await store.send(\.binding.displayName, "New Name") {
      $0.displayName = "New Name"
    }
    await store.send(\.binding.notes, "Important notes") {
      $0.notes = "Important notes"
    }
    await store.send(\.binding.visible, false) {
      $0.visible = false
    }

    await store.send(\.saveButtonTapped)

    let changed = Preset.with(id: preset.id)!
    #expect(changed.displayName == "New Name")
    #expect(changed.notes == "Important notes")
    #expect(changed.kind == .hidden)
  }

  @Test func cancelButtonTappedIgnoresChanges() async throws {
    let (preset, store) = try setup()

    await store.send(\.binding.displayName, "New Name") {
      $0.displayName = "New Name"
    }
    await store.send(\.binding.notes, "Important notes") {
      $0.notes = "Important notes"
    }
    await store.send(\.binding.visible, false) {
      $0.visible = false
    }

    await store.send(\.cancelButtonTapped)

    let changed = Preset.with(id: preset.id)!
    #expect(changed == store.state.preset)
  }

  @Test func useOriginalNameButtonTappedResetsNameChanges() async throws {
    let (_, store) = try setup()

    await store.send(\.displayNameChanged, "New Name") {
      $0.displayName = "New Name"
    }
    await store.send(\.notesChanged, "Important notes") {
      $0.notes = "Important notes"
    }
    await store.send(\.useOriginalNameTapped) {
      $0.displayName = store.state.preset.displayName
    }
  }

  @Test func resetGainTapped() async throws {
    let (_, store) = try setup()

    await store.send(\.binding.gainSlider, 0.5) {
      $0.gainSlider = 0.5
    }
    await store.send(\.resetGainTapped) {
      $0.gainSlider = 0.0
    }
  }

  @Test func resetPanTapped() async throws {
    let (_, store) = try setup()

    await store.send(\.binding.panSlider, 0.75) {
      $0.panSlider = 0.75
    }
    await store.send(\.resetPanTapped) {
      $0.panSlider = 0.0
    }
  }

  @Test func useLowestKeyTapped() async throws {
    let (_, store) = try setup()
    @Shared(.firstVisibleKey) var lowestKey = .A4
    await store.send(\.useLowestKeyTapped) {
      $0.pendingAudioConfig.keyboardLowestNote = .init(midiNoteValue: 69)
    }
  }

  @Test func presetEditorPreview() async throws {
    try withSnapshotTesting(record: .failed) {
      try BaseTestSuite.assertSnap(
        matching: PresetEditorView.preview,
        size: .init(width: 400, height: 800),
        colorScheme: .dark
      )
    }
  }
}
