import ComposableArchitecture
import Dependencies
import SnapshotTesting
import SwiftUI
import Tagged
import Testing

@testable import SoundFonts2

@MainActor
struct TagNameEditorTests {

  func initialize(_ body: (TestStoreOf<TagNameEditor>) async throws -> Void) async throws {
    try await withDependencies {
      $0.defaultDatabase = try appDatabase()
    } operation: {
      let newTag = try Tag.make(displayName: "New Tag")
      try await body(TestStore(initialState: TagNameEditor.State(id: newTag.id, draft: Tag.Draft(newTag))) {
        TagNameEditor()
      })
    }
  }

  @Test func deleteTag() async throws {
    try await initialize { store in
      await store.send(.tagSwipedToDelete)
      await store.receive(.delegate(.tagSwipedToDelete(store.state.id)))
      await store.finish()
    }
  }

  @Test func nameChanged() async throws {
    try await initialize { store in
      await store.send(.nameChanged("Blah")) {
        $0.draft.displayName = "Blah"
      }
      await store.send(.nameChanged("")) {
        $0.draft.displayName = ""
      }
    }
  }

  @Test func tagNameEditorPreview() async throws {
    withSnapshotTesting(record: .failed) {
      struct HostView: SwiftUI.View {
        var body: some SwiftUI.View {
          TagNameEditorView.preview
        }
      }
      let view = HostView()
      assertSnapshot(of: view, as: .image(layout: .device(config: .iPhoneSe), traits: .init(userInterfaceStyle: .dark)))
    }
  }
}
