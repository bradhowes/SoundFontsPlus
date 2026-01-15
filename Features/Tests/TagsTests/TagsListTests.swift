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

  @Test
  func deleteButtonTapped() async throws {
    @Shared(.activeState) var activeState = .default
    $activeState.withLock { $0.activeTagId = FontTag.Ubiquitous.external.id }

    let store = try store()
    let tagInfos = store.state.tagInfos
    #expect(tagInfos.count == 6)
    #expect(tagInfos.last?.displayName == "My New Tag")

    await store.send(.deleteButtonTapped(tagInfos.last!))

    let found = withDatabaseReader { db in
      try TagInfo.query.fetchAll(db)
    }

    #expect(found?.count == 5)
    #expect(activeState.activeTagId == FontTag.Ubiquitous.external.id)
  }

  @Test
  func tagButtonTapped() async throws {
    @Shared(.activeState) var activeState = .default
    #expect(activeState.activeTagId == FontTag.Ubiquitous.all.id)

    let store = try store()
    await store.send(.tagButtonTapped(store.state.tagInfos.last!))
    #expect(activeState.activeTagId == store.state.tagInfos.last!.id)
  }

  @Test
  func preview() async throws {
    try TestSupport.assertSnapshot(matching: TagsListView.preview)
  }
}
