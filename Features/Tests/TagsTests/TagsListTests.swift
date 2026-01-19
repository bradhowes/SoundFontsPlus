// Copyright © 2025 Brad Howes. All rights reserved.

import DependenciesTestSupport
import FeatureSupport
import SnapshotTesting
import Testing
import TestSupport

@testable import Tags

@Suite(
  .dependencies {
    $0.defaultDatabase = TestSupport.testDatabase()
    @Shared(.hideEmptyTags) var hideEmptyTags: Bool = false
  },
  .snapshots(record: .failed)
)
@MainActor
struct TagsListTests {

  func initialized(_ closure: (TestStoreOf<TagsList>) async throws -> Void) async throws {
    _ = try Tag.make(displayName: "My New Tag")
    let store = TestStore(initialState: TagsList.State()) { TagsList() }

    await store.send(\.initialize)
    await store.receive(\.updateFetchAllQuery)
    try await closure(store)

    await store.send(\.deinitialize)
    await store.finish()
  }

  @Test
  func deleteButtonTapped() async throws {
    @Shared(.activeState) var activeState = .default
    $activeState.withLock { $0.activeTagId = Tag.Ubiquitous.external.id }

    try await initialized { store in
      let tagInfos = store.state.tagInfos
      #expect(tagInfos.count == 6)
      #expect(tagInfos.last?.displayName == "My New Tag")

      guard let tagInfo = tagInfos.last else { fatalError() }
      await store.send(.deleteButtonTapped(tagInfo))

      let found = withDatabaseReader { db in
        try TagInfo.queryAll.fetchAll(db)
      }

      #expect(found?.count == 5)
      #expect(activeState.activeTagId == Tag.Ubiquitous.external.id)
    }
  }

  @Test
  func tagButtonTapped() async throws {
    @Shared(.activeState) var activeState = .default
    #expect(activeState.activeTagId == Tag.Ubiquitous.all.id)

    try await initialized { store in
      await store.send(.tagButtonTapped(store.state.tagInfos.last!))
      #expect(activeState.activeTagId == store.state.tagInfos.last!.id)
    }
  }

  @Test
  func preview() async throws {
    try TestSupport.assertSnapshot(matching: TagsListView.preview)
  }
}
