import ComposableArchitecture
import TestSupport
import Dependencies
import DependenciesTestSupport
import Models
import SnapshotTesting
import SwiftUI
import Tagged
import Testing

@testable import Tags

@Suite(
  .dependencies {
    $0.defaultDatabase = try appDatabase()
  },
  //  .snapshots(record: .failed)
)
@MainActor
struct TagNameEditorTests {

  func initialize(_ body: (TestStoreOf<TagNameEditor>) async throws -> Void) async throws {
    try await withDependencies {
      $0.defaultDatabase = try appDatabase()
    } operation: {
      let newTag = try FontTag.make(displayName: "New Tag")
      try await body(TestStore(initialState: TagNameEditor.State(id: newTag.id, draft: FontTag.Draft(newTag))) {
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

  @Test func tagNameEditorPreview() async throws {
    try withSnapshotTesting(record: .failed) {
      try TestSupport.assertSnapshot(matching: TagNameEditorView.preview)
    }
  }
}
