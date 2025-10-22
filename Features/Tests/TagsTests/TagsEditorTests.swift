// Copyright © 2025 Brad Howes. All rights reserved.

import DependenciesTestSupport
import FeatureSupport
import SnapshotTesting
import Testing
import TestSupport

@testable import Tags

@Suite(
  .dependencies { $0.defaultDatabase = try appDatabase() },
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
        id: -1,
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
        id: -2,
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
        id: -1,
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
        id: -2,
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
        id: -1,
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
        id: -1,
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
    await store.receive(.finalizeDeleteTag(tagId: -1)) {
      $0.rows = rows
      $0.focused = nil
    }
  }

  @Test func deleteButtonTappedOnOld() async {
    let store = store(mode: .tagEditing, soundFontId: 1, memberships: [:])
    var rows = store.state.rows

    await store.send(.deleteButtonTapped(at: IndexSet([1])))

    rows.remove(at: 0)
    await store.receive(.finalizeDeleteTag(tagId: 1)) {
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
    await store.receive(.finalizeDeleteTag(tagId: 1)) {
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
        id: -1,
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
    await store.receive(.finalizeDeleteTag(tagId: 1)) {
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

//import ComposableArchitecture
//import Dependencies
//import SnapshotTesting
//import SwiftUI
//import Tagged
//import Testing
//
//@testable import SoundFontsPlus
//
//@MainActor
//struct TagsEditorTests {
//
//  func initialize(_ body: (TestStoreOf<TagsEditor>) async throws -> Void) async throws {
//    try await withDependencies {
//      $0.defaultDatabase = try appDatabase()
//    } operation: {
//      let _ = try Tag.make(displayName: "New Tag")
//      try await body(TestStore(initialState: TagsEditor.State(focused: nil)) {
//        TagsEditor()
//      })
//    }
//  }
//
//  @Test func addButtonTapped() async throws {
//    try await initialize { store in
//      #expect(store.state.rows.count == 5)
//      #expect(store.state.focused == nil)
//      await store.send(.addButtonTapped) {
//        $0.rows.append(TagNameEditor.State(tag: Tag(id: 6, displayName: "New Tag 1", ordering: 6)))
//        $0.focused = 6
//      }
//    }
//  }
//
//  @Test func deleteTag() async throws {
//    try await initialize { store in
//      await store.send(.addButtonTapped) {
//        let tags = Tag.ordered
//        $0.rows.append(TagNameEditor.State(tag: tags[4]))
//        $0.focused = 5
//      }
//
//      await store.send(.tagSwipedToDelete(at: IndexSet(integer: 5)))
//      await store.receive(.finalizeDeleteTag(Tag.ID(rawValue: 5))) {
//        $0.rows.remove(id: 5)
//      }
//    }
//  }
//
//  @Test func rowDeleteTag() async throws {
//    try await initialize { store in
//
//      await store.send(.addButtonTapped) {
//        let tags = Tag.ordered
//        $0.rows.append(TagNameEditor.State(tag: tags[4]))
//        $0.focused = 5
//      }
//
//      await store.send(.rows(.element(id: 5, action: .delegate(.tagSwipedToDelete(store.state.rows[4].id)))))
//
//      await store.receive(.finalizeDeleteTag(Tag.ID(rawValue: 5))) {
//        $0.rows.remove(id: 5)
//      }
//    }
//  }
//
//  @Test func saveButtonTapped() async throws {
//    try await initialize { store in
//
//      await store.send(.addButtonTapped) {
//        let tags = Tag.ordered
//        $0.rows.append(TagNameEditor.State(tag: tags[4]))
//        $0.focused = 5
//      }
//
//      await store.send(.rows(.element(id: 5, action: .nameChanged("Happy")))) {
//        $0.rows[4].newName = "Happy"
//      }
//
//      await store.send(.addButtonTapped) {
//        let tags = Tag.ordered
//        $0.rows.append(TagNameEditor.State(tag: tags[5]))
//        $0.focused = 6
//      }
//
//      await store.send(.rows(.element(id: 6, action: .nameChanged("Birthday")))) {
//        $0.rows[5].newName = "Birthday"
//      }
//
//      await store.send(.tagMoved(at: IndexSet(integer: 5), to: 0)) {
//        $0.rows.move(fromOffsets: IndexSet(integer: 5), toOffset: 0)
//      }
//
////      await store.send(.saveButtonTapped)
//
//      let tags = Tag.ordered
//      #expect(tags.count == 6)
//      #expect(tags[5].displayName == "Happy")
//      #expect(tags[0].displayName == "Birthday")
//    }
//  }
//
//  @Test func toggleEditMode() async throws {
//    try await initialize { store in
//      await store.send(.toggleEditMode) {
//        $0.editMode = .active
//      }
//      await store.send(.toggleEditMode) {
//        $0.editMode = .inactive
//      }
//    }
//  }
//
//  @Test func tagsEditorPreview() async throws {
//    withSnapshotTesting(record: .failed) {
//      struct HostView: SwiftUI.View {
//        var body: some SwiftUI.View {
//          TagsEditorView.preview
//        }
//      }
//      let view = HostView()
//      assertSnapshot(of: view, as: .image(layout: .device(config: .iPhoneSe), traits: .init(userInterfaceStyle: .dark)))
//    }
//  }
//
//  @Test func tagsEditorInEditModePreview() async throws {
//    withSnapshotTesting(record: .failed) {
//      struct HostView: SwiftUI.View {
//        var body: some SwiftUI.View {
//          TagsEditorView.previewInEditMode
//        }
//      }
//      let view = HostView()
//      assertSnapshot(of: view, as: .image(layout: .device(config: .iPhoneSe), traits: .init(userInterfaceStyle: .dark)))
//    }
//  }
//}
