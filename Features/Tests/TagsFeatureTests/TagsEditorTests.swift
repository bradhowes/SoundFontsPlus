import Testing

import ComposableArchitecture
import Dependencies
import GRDB
import Models
import SF2ResourceFiles
import SnapshotTesting
import SwiftUI
import Tagged
@testable import TagsFeature

@MainActor
struct TagsEditorTests {

  func initialize(_ body: (TestStoreOf<TagsEditor>) async throws -> Void) async throws {
    try await TestSupport.initialize { tags in
      @Dependency(\.defaultDatabase) var database
      try await body(TestStore(initialState: TagsEditor.State(focused: nil)) {
        TagsEditor()
      })
    }
  }

  @Test func addButtonTapped() async throws {
    try await initialize { store in
      #expect(store.state.rows.count == 4)
      #expect(store.state.focused == nil)

      await store.send(.addButtonTapped) {
        @Dependency(\.defaultDatabase) var database
        let tag = try! database.read { try Tag.fetchOne($0, id: 5) }
        $0.rows.append(TagNameEditor.State(tag: tag!))
        $0.focused = 5
      }
    }
  }

  @Test func deleteTag() async throws {
    try await initialize { store in
      await store.send(.addButtonTapped) {
        @Dependency(\.defaultDatabase) var database
        let tag = try! database.read { try Tag.fetchOne($0, id: 5) }
        $0.rows.append(TagNameEditor.State(tag: tag!))
        $0.focused = 5
      }

      await store.send(.deleteTag(at: IndexSet(integer: 5)))
      await store.receive(.finalizeDeleteTag(IndexSet(integer: 5))) {
        $0.rows.remove(id: 5)
      }
    }
  }

  @Test func rowDeleteTag() async throws {
    try await initialize { store in

      await store.send(.addButtonTapped) {
        @Dependency(\.defaultDatabase) var database
        let tag = try! database.read { try Tag.fetchOne($0, id: 5) }
        $0.rows.append(TagNameEditor.State(tag: tag!))
        $0.focused = 5
      }

      await store.send(.rows(.element(id: 5, action: .delegate(.deleteTag(store.state.rows[4].id)))))

      await store.receive(.finalizeDeleteTag(IndexSet(integer: 5))) {
        $0.rows.remove(id: 5)
      }
    }
  }

  @Test func saveButtonTapped() async throws {
    try await initialize { store in

      await store.send(.addButtonTapped) {
        @Dependency(\.defaultDatabase) var database
        let tag = try! database.read { try Tag.fetchOne($0, id: 5) }
        $0.rows.append(TagNameEditor.State(tag: tag!))
        $0.focused = 5
      }

      await store.send(.rows(.element(id: 5, action: .nameChanged("Happy")))) {
        $0.rows[4].name = "Happy"
      }

      await store.send(.addButtonTapped) {
        @Dependency(\.defaultDatabase) var database
        let tag = try! database.read { try Tag.fetchOne($0, id: 6) }
        $0.rows.append(TagNameEditor.State(tag: tag!))
        $0.focused = 6
      }

      await store.send(.rows(.element(id: 6, action: .nameChanged("Birthday")))) {
        $0.rows[5].name = "Birthday"
      }

      await store.send(.tagMoved(at: IndexSet(integer: 5), to: 0)) {
        $0.rows.move(fromOffsets: IndexSet(integer: 5), toOffset: 0)
      }

//      await store.send(.saveButtonTapped)

      let tags = Tag.ordered
      #expect(tags.count == 6)
      #expect(tags[5].name == "Happy")
      #expect(tags[0].name == "Birthday")
    }
  }

  @Test func toggleEditMode() async throws {
    try await initialize { store in
      await store.send(.toggleEditMode) {
        $0.editMode = .active
      }
      await store.send(.toggleEditMode) {
        $0.editMode = .inactive
      }
    }
  }

  @Test func tagsEditorPreview() async throws {
    withSnapshotTesting(record: .failed) {
      struct HostView: SwiftUI.View {
        var body: some SwiftUI.View {
          TagsEditorView.preview
        }
      }
      let view = HostView()
      assertSnapshot(of: view, as: .image(layout: .device(config: .iPhoneSe), traits: .init(userInterfaceStyle: .dark)))
    }
  }

  @Test func tagsEditorInEditModePreview() async throws {
    withSnapshotTesting(record: .failed) {
      struct HostView: SwiftUI.View {
        var body: some SwiftUI.View {
          TagsEditorView.previewInEditMode
        }
      }
      let view = HostView()
      assertSnapshot(of: view, as: .image(layout: .device(config: .iPhoneSe), traits: .init(userInterfaceStyle: .dark)))
    }
  }
}
