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
      try await body(TestStore(initialState: TagsEditor.State(tags: tags, focused: nil)) {
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
}
