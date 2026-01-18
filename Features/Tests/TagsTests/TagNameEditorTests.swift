// Copyright © 2025 Brad Howes. All rights reserved.

import DependenciesTestSupport
import FeatureSupport
import SnapshotTesting
import Testing
import TestSupport

@testable import Tags

@Suite(
  .snapshots(record: .failed)
)
@MainActor
struct TagNameEditorTests {

  func store(membership: Bool? = nil) throws -> TestStoreOf<TagNameEditor> {
    let tag = Tag(id: 5, displayName: "New Tag", ordering: 5)
    return TestStore(
      initialState: TagNameEditor.State(
        tagId: tag.id,
        draft: Tag.Draft(tag),
        membership: membership
      )
    ) {
      TagNameEditor()
    }
  }

  @Test
  func deleteTag() async throws {
    let store = try store()
    await store.send(.tagSwipedToDelete)
    await store.receive(\.delegate, .tagSwipedToDelete(store.state.id))
    await store.finish()
  }

  @Test
  func membershipButtonTapped() async throws {
    let store = try store(membership: false)
    await store.send(.binding(.set(\.membership, true))) {
      $0.membership = true
    }
    await store.send(.binding(.set(\.membership, false))) {
      $0.membership = false
    }
    await store.finish()
  }

  @Test
  func tagNameEditorPreview() async throws {
    try TestSupport.assertSnapshot(matching: TagNameEditorView.preview)
  }
}
