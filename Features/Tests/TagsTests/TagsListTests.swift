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
struct TagsListTests {

  func store() throws -> TestStoreOf<TagsList> {
    _ = try FontTag.make(displayName: "My New Tag")
    return TestStore(initialState: TagsList.State()) { TagsList() }
  }

  @Test func deleteButtonTapped() async throws {
    @Shared(.activeState) var activeState = .default
    $activeState.withLock { $0.activeTagId = 5 }

    let store = try store()
    let tagInfos = store.state.tagInfos
    #expect(tagInfos.count == 5)
    #expect(tagInfos.last?.displayName == "My New Tag")

    await store.send(.deleteButtonTapped(tagInfos.last!))

    let found = withDatabaseReader { db in
      try TagInfo.query.fetchAll(db)
    }

    #expect(found?.count == 4)
    #expect(activeState.activeTagId == FontTag.Ubiquitous.all.id)
  }

  @Test func editButtonTapped() async throws {
    let store = try store()
    await store.send(.editButtonTapped(store.state.tagInfos[0]))
    await store.receive(\.delegate, .edit(store.state.tagInfos[0].id))
    await store.send(.editButtonTapped(store.state.tagInfos.last!))
    await store.receive(\.delegate, .edit(store.state.tagInfos.last!.id))
  }

  @Test func tagButtonTapped() async throws {
    @Shared(.activeState) var activeState = .default
    #expect(activeState.activeTagId == 1)

    let store = try store()
    await store.send(.tagButtonTapped(store.state.tagInfos.last!))
    #expect(activeState.activeTagId == store.state.tagInfos.last!.id)
  }

  @Test func longPressGestureFired() async throws {
    let store = try store()
    await store.send(.longPressGestureFired)
    await store.receive(\.delegate, .edit(nil))
  }

  @Test func preview() async throws {
    try TestSupport.assertSnapshot(matching: TagsListView.preview)
  }
}




//  func initialize(_ body: (TestStoreOf<TagsList>) async throws -> Void) async throws {
//    try await withDependencies {
//      $0.defaultDatabase = try appDatabase()
//    } operation: {
//      let _ = try Tag.make(displayName: "New Tag")
//      @Shared(.activeState) var activeState
//      $activeState.withLock {
//        $0.activeTagId = Tag.Ubiquitous.all.id
//      }
//      try await body(TestStore(initialState: TagsList.State()) {
//        TagsList()
//      })
//    }
//  }
//
//  @Test func creation() async throws {
//    try await initialize { store in
//      #expect(store.state.rows.count == 4)
//      await store.send(.onAppear)
//      await store.finish()
//    }
//  }
//
//  @Test func addButtonTapped() async throws {
//    try await initialize { store in
//      #expect(store.state.rows.count == 4)
//      await store.send(.addButtonTapped) {
//        let tags = Operations.orderedTags
//        $0.rows.append(TagButton.State(tagInfo: .init(tag: tags[4])))
//      }
//      await store.finish()
//    }
//  }
//
//  @Test func rowEditButtonTapped() async throws {
//    try await initialize { store in
//      #expect(store.state.rows.count == 4)
//      await store.send(.rows(.element(id:1, action: .delegate(.editTags)))) {
//        $0.destination = .edit(TagsEditor.State(focused: nil))
//      }
//
//      await store.send(.destination(.dismiss)) {
//        $0.destination = nil
//      }
//
//      await store.finish()
//    }
//  }
//
//  @Test func rowDeleteButtonTapped() async throws {
//    try await initialize { store in
//      #expect(store.state.rows.count == 5)
//      await store.send(.rows(.element(id:1, action: .delegate(.deleteTag(store.state.rows[4].tagInfo)))))
//      await store.receive(\.fetchTags) {
//        $0.rows.remove(at: 4)
//      }
//      await store.finish()
//    }
//  }
//
//  @Test func activeRowDeleteButtonTapped() async throws {
//    try await initialize { store in
//      #expect(store.state.rows.count == 4)
//      @Shared(.activeState) var activeState
//
//      await store.send(.addButtonTapped) {
//        let tags = Operations.orderedTags
//        $0.rows.append(TagButton.State(tagInfo: .init(tag: tags[4])))
//      }
//      #expect(store.state.rows.count == 5)
//
//      await store.send(.rows(.element(id: 5, action: .buttonTapped)))
//      #expect(activeState.activeTagId == 5)
//
//      await store.send(.rows(.element(id:1, action: .delegate(.deleteTag(store.state.rows[4].tagInfo)))))
//      await store.receive(\.fetchTags) {
//        $0.rows.remove(at: 4)
//      }
//
//      #expect(activeState.activeTagId == Tag.Ubiquitous.all.id)
//
//      await store.finish()
//    }
//  }
//
//  @Test func editorAddButtonTapped() async throws {
//    try await initialize { store in
//      #expect(store.state.rows.count == 4)
//
//      await store.send(.rows(.element(id:1, action: .delegate(.editTags)))) {
//        $0.destination = .edit(TagsEditor.State(focused: nil))
//      }
//
//      store.exhaustivity = .off
//      await store.send(.destination(.presented(.edit(.addButtonTapped)))) {
//        let tags = Operations.orderedTags
//        $0.rows.append(TagButton.State(tagInfo: .init(tag: tags[4])))
//      }
//      store.exhaustivity = .on
//
//      await store.finish()
//    }
//  }
//
//  @Test func editorDeleteButtonTapped() async throws {
//    try await initialize { store in
//      #expect(store.state.rows.count == 4)
//
//      await store.send(.rows(.element(id:1, action: .delegate(.editTags)))) {
//        $0.destination = .edit(TagsEditor.State(focused: nil))
//      }
//
//      await store.send(.destination(.presented(.edit(.addButtonTapped)))) {
//        let tags = Operations.orderedTags
//        $0.rows.append(TagButton.State(tagInfo: .init(tag: tags[4])))
//        $0.destination = .edit(TagsEditor.State(focused: Tag.ID(rawValue: 5)))
//      }
//
//      store.exhaustivity = .on
//      await store.send(.destination(.presented(.edit(.finalizeDeleteTag(.init(integer: 5)))))) {
//        $0.rows.remove(id: 5)
//        $0.destination = .edit(TagsEditor.State(focused: Tag.ID(rawValue: 5)))
//      }
//
//      let tag = Operations.tag(5)
//      #expect(tag == nil)
//
//      await store.finish()
//    }
//  }
//
//  @Test func tagsListViewPreview() async throws {
//    withSnapshotTesting(record: .failed) {
//      struct HostView: SwiftUI.View {
//        var body: some SwiftUI.View {
//          TagsListView.preview
//            .environment(\.editMode, .constant(.inactive))
//        }
//      }
//      let view = HostView()
//      assertSnapshot(of: view, as: .image(layout: .device(config: .iPhoneSe), traits: .init(userInterfaceStyle: .dark)))
//    }
//  }
//
//  @Test func tagsListWithEditorPreview() async throws {
//    withSnapshotTesting(record: .failed) {
//      struct HostView: SwiftUI.View {
//        var body: some SwiftUI.View {
//          TagsListView.previewWithEditor
//            .environment(\.editMode, .constant(.inactive))
//        }
//      }
//      let view = HostView()
//      assertSnapshot(of: view, as: .image(layout: .device(config: .iPhoneSe), traits: .init(userInterfaceStyle: .dark)))
//    }
//  }
//}
//
