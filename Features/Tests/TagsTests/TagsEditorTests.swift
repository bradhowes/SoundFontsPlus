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

  func tagEditingStore(
    focused: Int? = nil,
    editModeActive: Bool = false
  ) -> TestStoreOf<TagsEditor> {
    return TestStore(
      initialState: TagsEditor.State(
        focused: focused,
        editModeActive: editModeActive
      )
    ) {
      TagsEditor()
    }
  }

  func fontEditingStore(
    soundFontId: SoundFont.ID,
    memberships: [Models.Tag.ID: Bool],
    editModeActive: Bool = false
  ) -> TestStoreOf<TagsEditor> {
    return TestStore(
      initialState: TagsEditor.State(
        soundFontId: soundFontId,
        memberships: memberships,
        editModeActive: editModeActive
      )
    ) {
      TagsEditor()
    }
  }

  @Test
  func addButtonTappedNoPrompt() async {
    @Shared(.hideEmptyTags) var hideEmptyTags: Bool = false

    let store = tagEditingStore()
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
  func addButtonTappedWithPrompt() async {
    @Shared(.hideEmptyTags) var hideEmptyTags: Bool = true

    let store = tagEditingStore()
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
    // $0.destination = .alert(.tagWillBeHidden(displayName: "New Tag"))
    // }

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
      // $0.destination = .alert(.tagWillBeHidden(displayName: "New Tag 1"))
    }
  }

  @Test
  func addButtonTappedForFont() async {
    let store = fontEditingStore(soundFontId: 1, memberships: [:])
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
    @Shared(.hideEmptyTags) var hideEmptyTags
    $hideEmptyTags.withLock { $0 = false }

    let store = tagEditingStore()
    var rows = store.state.rows
    #expect(rows.count == 5)

    rows.append(
      .init(
        tagId: nil,
        draft: .init(displayName: "New Tag", ordering: rows.count),
      )
    )
    rows[5].membership = true

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
    @Shared(.hideEmptyTags) var hideEmptyTags
    $hideEmptyTags.withLock { $0 = false }

    let store = tagEditingStore()
    var rows = store.state.rows
    #expect(rows.count == 5)

    let rowId = rows.count
    rows.append(
      .init(
        tagId: nil,
        draft: .init(displayName: "New Tag", ordering: rows.count),
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
    let store = tagEditingStore()
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
    let store = tagEditingStore()
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
    let store = fontEditingStore(soundFontId: 1, memberships: [:])
    await store.send(.deleteButtonTapped(at: IndexSet([99_999])))
    await store.receive(\.finalizeDeleteTag, 99_999)
  }

  @Test
  func saveButtonTapped() async {
    @Shared(.hideEmptyTags) var hideEmptyTags
    $hideEmptyTags.withLock { $0 = false }

    let store = tagEditingStore()
    var rows = store.state.rows
    #expect(rows.count == 5)

    rows.append(
      .init(
        tagId: nil,
        draft: .init(displayName: "New Tag", ordering: rows.count),
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
    let store = tagEditingStore()
    var rows = store.state.rows
    rows.move(fromOffsets: IndexSet([1]), toOffset: 3)
    await store.send(.tagMoved(at: IndexSet([1]), to: 3)) {
      $0.rows = rows
    }
  }

  @Test
  func toggleEditMode() async {
    let store = tagEditingStore()
    await store.send(.toggleEditModeActive) {
      $0.editModeActive = true
    }
    await store.send(.toggleEditModeActive) {
      $0.editModeActive = false
    }
  }

  @Test
  func preview() async throws {
    TestSupport.assertSnapshot(matching: TagsEditorView.preview)
  }

  @Test
  func previewInEditMode() async throws {
    TestSupport.assertSnapshot(matching: TagsEditorView.previewInEditMode)
  }

  @Test
  func previewWithMemberships() async throws {
    TestSupport.assertSnapshot(matching: TagsEditorView.previewWithMemberships)
  }

  @Test
  func previewWithMembershipsInEditMode() async throws {
    TestSupport.assertSnapshot(matching: TagsEditorView.previewWithMembershipsInEditMode)
  }
}
