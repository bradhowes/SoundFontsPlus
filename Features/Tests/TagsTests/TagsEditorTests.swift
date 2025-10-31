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
    focused: FontTag.ID? = nil,
    soundFontId: SoundFont.ID? = nil,
    memberships: [FontTag.ID: Bool]? = nil,
    editMode: EditMode = .inactive
  ) -> TestStoreOf<TagsEditor> {
    return TestStore(
      initialState: TagsEditor.State(
        mode: mode,
        focused: focused,
        soundFontId: soundFontId,
        memberships: memberships,
        editMode: editMode
      )
    ) {
      TagsEditor()
    }
  }

  @Test func addButtonTapped() async {
    let store = store(mode: .tagEditing)
    var rows = store.state.rows
    #expect(rows.count == 4)
    rows.append(
      .init(
        tagId: -1,
        draft: .init(displayName: "New Tag", ordering: rows.count),
        membership: nil
      )
    )

    await store.send(.addButtonTapped) {
      $0.rows = rows
      $0.focused = -1
    }

    rows.append(
      .init(
        tagId: -2,
        draft: .init(displayName: "New Tag 1", ordering: rows.count),
        membership: nil
      )
    )

    await store.send(.addButtonTapped) {
      $0.rows = rows
      $0.focused = -2
    }
  }

  @Test func addButtonTappedForFont() async {
    let store = store(mode: .fontEditing, soundFontId: 1, memberships: [:])
    var rows = store.state.rows
    #expect(rows.count == 4)

    rows.append(
      .init(
        tagId: -1,
        draft: .init(displayName: "New Tag", ordering: rows.count),
        membership: false
      )
    )

    await store.send(.addButtonTapped) {
      $0.rows = rows
      $0.focused = -1
    }

    rows.append(
      .init(
        tagId: -2,
        draft: .init(displayName: "New Tag 1", ordering: rows.count),
        membership: false
      )
    )

    await store.send(.addButtonTapped) {
      $0.rows = rows
      $0.focused = -2
    }
  }

  @Test func cancelButtonTapped() async {
    let store = store(mode: .tagEditing, soundFontId: 1, memberships: [:])
    var rows = store.state.rows
    #expect(rows.count == 4)

    rows.append(
      .init(
        tagId: -1,
        draft: .init(displayName: "New Tag", ordering: rows.count),
        membership: false
      )
    )

    await store.send(.addButtonTapped) {
      $0.rows = rows
      $0.focused = -1
    }

    await store.send(.cancelButtonTapped)

    let found = withDatabaseReader { db in
      try FontTag.all.fetchAll(db)
    } ?? []

    #expect(found.count == 4)
  }

  @Test func deleteButtonTappedOnNew() async {
    let store = store(mode: .tagEditing, soundFontId: 1, memberships: [:])
    var rows = store.state.rows
    #expect(rows.count == 4)

    rows.append(
      .init(
        tagId: -1,
        draft: .init(displayName: "New Tag", ordering: rows.count),
        membership: false
      )
    )

    await store.send(.addButtonTapped) {
      $0.rows = rows
      $0.focused = -1
    }

    rows.removeLast()

    await store.send(.deleteButtonTapped(at: IndexSet([-1])))
    await store.receive(\.finalizeDeleteTag, -1) {
      $0.rows = rows
      $0.focused = nil
    }
  }

  @Test func deleteButtonTappedOnOld() async {
    let store = store(mode: .tagEditing, soundFontId: 1, memberships: [:])
    var rows = store.state.rows

    await store.send(.deleteButtonTapped(at: IndexSet([1])))

    rows.remove(at: 0)
    await store.receive(\.finalizeDeleteTag, 1) {
      $0.rows = rows
      $0.focused = nil
      $0.deleted = Set([1])
    }
  }

  @Test func deleteButtonSwipedOnOld() async {
    let store = store(mode: .tagEditing)
    var rows = store.state.rows

    await store.send(.rows(.element(id: 1, action: .delegate(.tagSwipedToDelete(1)))))

    rows.remove(at: 0)
    await store.receive(\.finalizeDeleteTag, 1) {
      $0.rows = rows
      $0.focused = nil
      $0.deleted = Set([1])
    }
  }

  @Test func deleteButtonTappedInvalidIndex() async {
    let store = store(mode: .fontEditing, soundFontId: 1, memberships: [:])
    await store.send(.deleteButtonTapped(at: IndexSet([-1])))
  }

  @Test func saveButtonTapped() async {
    let store = store(mode: .tagEditing, soundFontId: 1, memberships: [:])
    var rows = store.state.rows
    #expect(rows.count == 4)

    rows.append(
      .init(
        tagId: -1,
        draft: .init(displayName: "New Tag", ordering: rows.count),
        membership: false
      )
    )

    await store.send(.addButtonTapped) {
      $0.rows = rows
      $0.focused = -1
    }

    await store.send(.deleteButtonTapped(at: IndexSet([1])))
    rows.remove(at: 0)
    await store.receive(\.finalizeDeleteTag, 1) {
      $0.rows = rows
      $0.deleted = Set([1])
    }

    await store.send(.saveButtonTapped)

    let found = withDatabaseReader { db in
      try FontTag.all.fetchAll(db)
    } ?? []

    #expect(found.count == 4)
    #expect(found.first(where: { $0.displayName == "New Tag" }) != nil)
  }

  @Test func tagMoved() async {
    let store = store(mode: .tagEditing)
    var rows = store.state.rows
    rows.move(fromOffsets: IndexSet([1]), toOffset: 3)
    await store.send(.tagMoved(at: IndexSet([1]), to: 3)) {
      $0.rows = rows
    }
  }

  @Test func toggleEditMode() async {
    let store = store(mode: .tagEditing)
    await store.send(.toggleEditMode) {
      $0.editMode = .active
    }
    await store.send(.toggleEditMode) {
      $0.editMode = .inactive
    }
  }

  @Test func preview() async throws {
    try TestSupport.assertSnapshot(matching: TagsEditorView.preview)
  }

  @Test func previewInEditMode() async throws {
    try TestSupport.assertSnapshot(matching: TagsEditorView.previewInEditMode)
  }

  @Test func previewWithMemberships() async throws {
    try TestSupport.assertSnapshot(matching: TagsEditorView.previewWithMemberships)
  }
}
