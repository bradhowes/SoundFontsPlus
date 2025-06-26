//import ComposableArchitecture
//import Dependencies
//import SnapshotTesting
//import SwiftUI
//import Tagged
//import Testing
//
//@testable import SoundFonts2
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
