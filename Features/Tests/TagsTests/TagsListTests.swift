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

  func initialized(
    makeTag: Bool = false,
    tagFont: Bool = false,
    _ closure: (TestStoreOf<TagsList>) async throws -> Void
  ) async throws {
    @Shared(.hideBuiltinFonts) var hideBuiltinFonts = false
    @Shared(.hideEmptyTags) var hideEmptyTags = false

    if makeTag {
      let tag = try Tag.make(displayName: "My New Tag")
      if tagFont {
        Operations.tagSoundFont(tag.id, soundFontId: SF2ResourceTag.rolandNicePiano.id)
      }
    }

    let store = TestStore(initialState: TagsList.State()) { TagsList() }

    await store.send(\.initialize)
    await store.receive(\.updateFetchAllQuery)
    await store.withExhaustivity(.off(showSkippedAssertions: false)) {
      await store.receive(\.rowsUpdated)
    }

    try await closure(store)

    await store.send(\.deinitialize)
    await store.finish()
  }

  @Test
  func deleteButtonTappedEmptyTag() async throws {
    @Shared(.activeState) var activeState = .default
    $activeState.withLock { $0.activeTagId = Tag.Ubiquitous.external.id }

    try await initialized(makeTag: true, tagFont: false) { store in
      let rows = store.state.rows
      let tagInfo = rows[5].tagInfo

      await store.send(\.rows[id: tagInfo.id].delegate.delete, tagInfo)
      await store.receive(\.rowsUpdated) {
        $0.rows = .init(rows.dropLast(1))
      }

      let found = withDatabaseReader { db in
        try TagInfo.queryAll.fetchAll(db)
      }

      #expect(found?.count == 5)
      #expect(activeState.activeTagId == Tag.Ubiquitous.external.id)
    }
  }

  @Test
  func deleteButtonTappedCancel() async throws {
    @Shared(.activeState) var activeState = .default
    $activeState.withLock { $0.activeTagId = Tag.Ubiquitous.external.id }

    try await initialized(makeTag: true, tagFont: true) { store in
      let rows = store.state.rows
      let tagInfo = rows[5].tagInfo

      await store.send(\.rows[id: tagInfo.id].delegate.delete, tagInfo) {
        $0.destination = .alert(
          .confirmDeleteTag(
            action: .deleteTagConfirmed(tagInfo),
            displayName: tagInfo.displayName,
            associationCount: tagInfo.soundFontsCount
          )
        )
      }

      await store.send(\.destination.dismiss) {
        $0.destination = nil
      }

      let found = withDatabaseReader { db in
        try TagInfo.queryAll.fetchAll(db)
      }

      #expect(found?.count == 6)
      #expect(activeState.activeTagId == Tag.Ubiquitous.external.id)
    }
  }

  @Test
  func deleteButtonTappedConfirmed() async throws {
    @Shared(.activeState) var activeState = .default

    try await initialized(makeTag: true, tagFont: true) { store in
      let rows = store.state.rows
      let tagInfo = rows[5].tagInfo
      $activeState.withLock { $0.activeTagId = tagInfo.id }

      await store.send(\.rows[id: tagInfo.id].delegate.delete, tagInfo) {
        $0.destination = .alert(
          .confirmDeleteTag(
            action: .deleteTagConfirmed(tagInfo),
            displayName: tagInfo.displayName,
            associationCount: tagInfo.soundFontsCount
          )
        )
      }

      await store.send(\.destination.presented.alert.deleteTagConfirmed, tagInfo) {
        $0.destination = nil
        // $0.rows = .init(rows.dropLast())
      }

      await store.receive(\.rowsUpdated) {
        $0.rows = .init(rows.dropLast(1))
      }

      let found = withDatabaseReader { db in
        try TagInfo.queryAll.fetchAll(db)
      }

      #expect(found?.count == 5)
      #expect(activeState.activeTagId == Tag.Ubiquitous.all.id)
    }
  }

  @Test
  func tagButtonTapped() async throws {
    @Shared(.activeState) var activeState = .default
    #expect(activeState.activeTagId == Tag.Ubiquitous.all.id)

    try await initialized(makeTag: true, tagFont: true) { store in
      let rows = store.state.rows
      let tagInfo = rows[5].tagInfo

      await store.send(\.rows[id: tagInfo.id].delegate.activate, tagInfo)
      #expect(activeState.activeTagId == tagInfo.id)
    }
  }

  @Test
  func editButtonTapped() async throws {
    @Shared(.activeState) var activeState = .default
    #expect(activeState.activeTagId == Tag.Ubiquitous.all.id)

    try await initialized(makeTag: true, tagFont: true) { store in
      let rows = store.state.rows
      let tagInfo = rows[5].tagInfo

      await store.send(\.rows[id: tagInfo.id].delegate.edit, tagInfo)
      await store.receive(\.delegate.edit, 5)
    }
  }

  @Test
  func trackChangesToHideEmptyTags() async throws {
    @Shared(.hideEmptyTags) var hideEmptyTags: Bool = false

    try await initialized(makeTag: true, tagFont: false) { store in
      let rows = store.state.rows
      #expect(rows.count == 6)

      $hideEmptyTags.withLock { $0 = true }

      await store.receive(\.updateFetchAllQuery)

      let filtered = rows.filter({ $0.tagInfo.soundFontsCount > 0})
      await store.receive(\.rowsUpdated, filtered.map(\.tagInfo)) {
        $0.rows = filtered
      }
    }
  }

  @Test
  func preview() async throws {
    try TestSupport.assertSnapshot(matching: TagsListView.preview)
  }
}
