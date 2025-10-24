// Copyright © 2025 Brad Howes. All rights reserved.

import DependenciesTestSupport
import FeatureSupport
import SnapshotTesting
import Tags
import Testing
import TestSupport

@testable import SoundFonts

@Suite(
  .dependencies {
    $0.defaultDatabase = try appDatabase()
  },
  .snapshots(record: .failed)
)
@MainActor
struct SoundFontEditorTests {
  let soundFontId: SoundFont.ID = 1

  func store() -> TestStoreOf<SoundFontEditor> {
    TestStore(initialState: SoundFontEditor.State(soundFont: .with(id: soundFontId)!)) {
      SoundFontEditor()
    }
  }

  @Test func cancelButtonTapped() async {
    let store = store()
    #expect(store.state.displayName == "Fluid R3")
    await store.send(.displayNameChanged("blah")) {
      $0.displayName = "blah"
    }
    await store.send(.cancelButtonTapped)
    let soundFont = SoundFont.with(id: 1)
    #expect(soundFont?.displayName == "Fluid R3")
  }

  @Test func changeTagsButtonTapped() async {
    let store = store()
    let editorState = TagsEditor.State(
      mode: .fontEditing,
      soundFontId: store.state.soundFont.id,
      memberships: store.state.memberships
    )
    await store.send(.changeTagsButtonTapped) {
      $0.path.append(.editTags(editorState))
    }
  }

  @Test func updatedTagsAfterEditing() async {
    let store = store()
    #expect(store.state.tagsList == "All, Built-in")

    let editorState = TagsEditor.State(
      mode: .fontEditing,
      soundFontId: store.state.soundFont.id,
      memberships: store.state.memberships
    )

    await store.send(.changeTagsButtonTapped) {
      $0.path.append(.editTags(editorState))
    }

    // Simulate toggling the membership for "external", which cannot normally be done in UI because the UI disables
    // manipulating ubiquitous tags that the app manages.
    withDatabaseWriter { db in
      try TaggedSoundFont.insert {
        .init(soundFontId: soundFontId, tagId: FontTag.Ubiquitous.external.id)
      }
      .execute(db)
    }

    await store.send(.path(.popFrom(id: store.state.path.ids[0]))) {
      $0.path = .init()
      $0.tagsList = "All, Built-in, External"
    }
  }

  @Test func showHiddenPresetsConfirmed() async {
    let store = store()

    var presets = Operations.presets(for: soundFontId)
    #expect(presets[0].kind == .preset)
    #expect(presets[0].displayName == "Yamaha Grand Piano")

    presets[0].toggleVisibility()

    presets = Operations.presets(for: soundFontId)
    #expect(presets[0].displayName == "Bright Yamaha Grand")

    await store.send(.unhideAllButtonTapped) {
      $0.destination = .alert(.confirmShowHiddenPresets(action: .showHiddenPresetsConfirmed))
    }

    await store.send(.destination(.presented(.alert(.showHiddenPresetsConfirmed)))) {
      $0.destination = nil
    }

    await store.receive(\.delegate.refreshPresets)

    presets = Operations.presets(for: soundFontId)
    #expect(presets[0].displayName == "Yamaha Grand Piano")
  }

  @Test func saveButtonTapped() async throws {
    let store = store()
    await store.send(.displayNameChanged("blah")) {
      $0.displayName = "blah"
    }
    await store.send(.notesChanged("notes")) {
      $0.notes = "notes"
    }
    await store.send(.saveButtonTapped)
    let soundFont = SoundFont.with(id: soundFontId)
    #expect(soundFont?.displayName == "blah")
  }

  @Test func useEmbeddedNameTapped() async throws {
    let store = store()
    await store.send(.displayNameChanged("blah")) {
      $0.displayName = "blah"
    }
    await store.send(.useEmbeddedNameTapped) {
      $0.displayName = "Fluid R3 GM"
    }
  }

  @Test func useOriginalNameTapped() async throws {
    let store = store()
    await store.send(.displayNameChanged("blah")) {
      $0.displayName = "blah"
    }
    await store.send(.useOriginalNameTapped) {
      $0.displayName = "Fluid R3"
    }
  }

  @Test func soundFontEditorViewPreview() async throws {
    try TestSupport.assertSnapshot(matching: SoundFontEditorView.preview)
  }
}
