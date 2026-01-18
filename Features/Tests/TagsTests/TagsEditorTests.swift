// Copyright © 2025 Brad Howes. All rights reserved.

import DependenciesTestSupport
import FeatureSupport
import SnapshotTesting
import Testing
import TestSupport

@testable import Tags

@Suite(
  .dependencies { $0.defaultDatabase = TestSupport.testDatabase() },
  .snapshots(record: .failed)
)
@MainActor
struct TagsEditorTests {

  func store(
    mode: TagsEditor.Mode,
    focused: Int? = nil,
    soundFontId: SoundFont.ID? = nil,
    memberships: [Tag.ID: Bool]? = nil,
    editModeActive: Bool = false
  ) -> TestStoreOf<TagsEditor> {
    return TestStore(
      initialState: TagsEditor.State(
        mode: mode,
        focused: focused,
        soundFontId: soundFontId,
        memberships: memberships,
        editModeActive: editModeActive
      )
    ) {
      TagsEditor()
    }
  }

  @Test
  func addButtonTapped() async {
    let store = store(mode: .tagEditing)
    var rows = store.state.rows
    #expect(rows.count == 5)
    rows.append(
      .init(
        tagId: nil,
        draft: .init(displayName: "New Tag", ordering: rows.count),
        membership: nil
      )
    )

    await store.send(.addButtonTapped) {
      $0.rows = rows
      $0.focused = 5
    }

    rows.append(
      .init(
        tagId: nil,
        draft: .init(displayName: "New Tag 1", ordering: rows.count),
        membership: nil
      )
    )

    await store.send(.addButtonTapped) {
      $0.rows = rows
      $0.focused = 6
    }
  }

  @Test
  func addButtonTappedForFont() async {
    let store = store(mode: .fontEditing, soundFontId: 1, memberships: [:])
    var rows = store.state.rows
    #expect(rows.count == 5)

    rows.append(
      .init(
        tagId: nil,
        draft: .init(displayName: "New Tag", ordering: rows.count),
        membership: false
      )
    )

    await store.send(.addButtonTapped) {
      $0.rows = rows
      $0.focused = 5
    }

    rows.append(
      .init(
        tagId: nil,
        draft: .init(displayName: "New Tag 1", ordering: rows.count),
        membership: false
      )
    )

    await store.send(.addButtonTapped) {
      $0.rows = rows
      $0.focused = 6
    }
  }

  @Test
  func cancelButtonTapped() async {
    let store = store(mode: .tagEditing, soundFontId: 1, memberships: [:])
    var rows = store.state.rows
    #expect(rows.count == 5)

    rows.append(
      .init(
        tagId: nil,
        draft: .init(displayName: "New Tag", ordering: rows.count),
        membership: false
      )
    )

    await store.send(.addButtonTapped) {
      $0.rows = rows
      $0.focused = 5
    }

    await store.send(.cancelButtonTapped)

    let found = withDatabaseReader { db in
      try Tag.all.fetchAll(db)
    } ?? []

    #expect(found.count == 5)
  }

  @Test
  func deleteButtonTappedOnNew() async {
    let store = store(mode: .tagEditing, soundFontId: 1, memberships: [:])
    var rows = store.state.rows
    #expect(rows.count == 5)

    let rowId = rows.count
    rows.append(
      .init(
        tagId: nil,
        draft: .init(displayName: "New Tag", ordering: rows.count),
        membership: false
      )
    )

    await store.send(.addButtonTapped) {
      $0.rows = rows
      $0.focused = rowId
    }

    rows.removeLast()

    await store.send(.deleteButtonTapped(at: IndexSet([rowId])))
    await store.receive(\.finalizeDeleteTag, rowId) {
      $0.rows = rows
      $0.focused = nil
    }
  }

  @Test
  func deleteButtonTappedOnOld() async {
    let store = store(mode: .tagEditing, soundFontId: 1, memberships: [:])
    var rows = store.state.rows
    let rowId = 0
    await store.send(.deleteButtonTapped(at: IndexSet([rowId])))

    let removed = rows.remove(at: rowId)
    await store.receive(\.finalizeDeleteTag, rowId) {
      $0.rows = rows
      $0.focused = nil
      $0.deleting = Set([removed.tagId!])
    }
  }

  @Test
  func deleteButtonSwipedOnOld() async {
    let store = store(mode: .tagEditing)
    var rows = store.state.rows

    let rowId = 1
    await store.send(.rows(.element(id: rowId, action: .delegate(.tagSwipedToDelete(rowId)))))

    let removed = rows.remove(at: rowId)
    await store.receive(\.finalizeDeleteTag, rowId) {
      $0.rows = rows
      $0.focused = nil
      $0.deleting = Set([removed.tagId!])
    }
  }

  @Test
  func deleteButtonTappedInvalidIndex() async {
    let store = store(mode: .fontEditing, soundFontId: 1, memberships: [:])
    await store.send(.deleteButtonTapped(at: IndexSet([99_999])))
    await store.receive(\.finalizeDeleteTag, 99_999)
  }

  @Test
  func saveButtonTapped() async {
    let store = store(mode: .tagEditing, soundFontId: 1, memberships: [:])
    var rows = store.state.rows
    #expect(rows.count == 5)

    rows.append(
      .init(
        tagId: nil,
        draft: .init(displayName: "New Tag", ordering: rows.count),
        membership: false
      )
    )

    await store.send(.addButtonTapped) {
      $0.rows = rows
      $0.focused = rows.count - 1
    }

    let rowId = 1
    await store.send(.deleteButtonTapped(at: IndexSet([rowId])))
    let removed = rows.remove(at: rowId)

    await store.receive(\.finalizeDeleteTag, rowId) {
      $0.rows = rows
      $0.deleting = Set([removed.tagId!])
    }

    await store.send(.saveButtonTapped)

    let found = withDatabaseReader { db in
      try Tag.all.fetchAll(db)
    } ?? []

    #expect(found.count == 5)
    #expect(found.first(where: { $0.displayName == "New Tag" }) != nil)
  }

  @Test
  func tagMoved() async {
    let store = store(mode: .tagEditing)
    var rows = store.state.rows
    rows.move(fromOffsets: IndexSet([1]), toOffset: 3)
    await store.send(.tagMoved(at: IndexSet([1]), to: 3)) {
      $0.rows = rows
    }
  }

  @Test
  func toggleEditMode() async {
    let store = store(mode: .tagEditing)
    await store.send(.toggleEditModeActive) {
      $0.editModeActive = true
    }
    await store.send(.toggleEditModeActive) {
      $0.editModeActive = false
    }
  }

  @Test
  func preview() async throws {
    try TestSupport.assertSnapshot(matching: TagsEditorView.preview)
  }

  @Test
  func previewInEditMode() async throws {
    try TestSupport.assertSnapshot(matching: TagsEditorView.previewInEditMode)
  }

  @Test
  func previewWithMemberships() async throws {
    try TestSupport.assertSnapshot(matching: TagsEditorView.previewWithMemberships)
  }
}
