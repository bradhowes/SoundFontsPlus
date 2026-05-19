// Copyright © 2025 Brad Howes. All rights reserved.

import DependenciesTestSupport
import FeatureSupport
import Models
import SnapshotTesting
import Testing
import TestSupport

@testable import Tags

@Suite(
  .dependencies {
    $0.defaultDatabase = TestSupport.testDatabase()
  },
  .snapshots(record: .failed)
)
@MainActor
struct TagsListTests {
  @Shared(.hideEmptyTags) var hideEmptyTags = false
  @Shared(.hideBuiltinFonts) var hideBuiltinFonts = false

  init() {
    $hideBuiltinFonts.withLock { $0 = false }
    $hideEmptyTags.withLock { $0 = false }
  }

  func initialized(
    makeTag: Bool = false,
    tagFont: Bool = false,
    activeTagId: Models.Tag.ID? = Tag.Ubiquitous.all.id,
    _ closure: (TestStoreOf<TagsList>) async throws -> Void
  ) async throws {
    if makeTag {
      let tag = try Tag.make(displayName: "My New Tag")
      if tagFont {
        SoundFont.link(soundFontId: SF2ResourceTag.rolandNicePiano.id, to: tag.id)
      }
    }

    let store = TestStore(initialState: TagsList.State(activeTagId: activeTagId)) { TagsList() }

    await store.send(\.initialize)
//    // await store.receive(\.updateFetchAllQuery)
//    await store.withExhaustivity(.off(showSkippedAssertions: false)) {
//      await store.receive(\.rowsUpdated)
//    }

    try await closure(store)

    await store.send(\.deinitialize)
    await store.finish()
  }

  @Test
  func deleteButtonTappedEmptyTag() async throws {
    $hideEmptyTags.withLock { $0 = false }
    $hideBuiltinFonts.withLock { $0 = false }

    try await initialized(
      makeTag: true,
      tagFont: false,
      activeTagId: Models.Tag.Ubiquitous.external.id
    ) { store in
      let rows = store.state.rows
      let tagInfo = rows[5]

      await store.send(\.tagInfoDeleteTapped, tagInfo)

      let found = withDatabaseReader { db in
        try TagInfo.query.fetchAll(db)
      }

      #expect(found?.count == 5)
      #expect(store.state.activeTagId == Tag.Ubiquitous.external.id)
    }
  }

  @Test
  func deleteButtonTappedCancel() async throws {
    try await initialized(makeTag: true, tagFont: true, activeTagId: Models.Tag.Ubiquitous.external.id) { store in
      let rows = store.state.rows
      let tagInfo = rows[5]

      await store.send(\.tagInfoDeleteTapped, tagInfo) {
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
        try TagInfo.query.fetchAll(db)
      }

      #expect(found?.count == 6)
      #expect(store.state.activeTagId == Models.Tag.Ubiquitous.external.id)
    }
  }

  @Test
  func deleteButtonTappedConfirmed() async throws {
    try await initialized(makeTag: true, tagFont: true, activeTagId: 6) { store in
      let rows = store.state.rows
      let tagInfo = rows[5]

      await store.send(\.tagInfoDeleteTapped, tagInfo) {
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

      let found = withDatabaseReader { db in
        try TagInfo.query.fetchAll(db)
      }

      #expect(found?.count == 5)
      #expect(store.state.activeTagId == 6)
    }
  }

  @Test
  func tagButtonTapped() async throws {
    try await initialized(makeTag: true, tagFont: true, activeTagId: Tag.Ubiquitous.all.id) { store in
      let rows = store.state.rows
      let tagInfo = rows[5]

      await store.send(\.tagInfoButtonTapped, tagInfo) {
        $0.activeTagId = 1
      }
      await store.receive(\.delegate.activeTagIdChanged, tagInfo.id)

      #expect(store.state.activeTagId == tagInfo.id)
    }
  }

  @Test
  func editButtonTapped() async throws {
    try await initialized(makeTag: true, tagFont: true, activeTagId: Tag.Ubiquitous.all.id) { store in
      let rows = store.state.rows
      let tagInfo = rows[5]

      await store.send(\.tagInfoEditTapped, tagInfo)
      await store.receive(\.delegate.edit, 5)
    }
  }

  @Test
  func trackChangesToQueryOptions() async throws {
    $hideBuiltinFonts.withLock { $0 = false }
    $hideEmptyTags.withLock { $0 = false }
    try await initialized(makeTag: true, tagFont: false) { store in
      #expect(store.state.tagInfos.count == 6)
      $hideBuiltinFonts.withLock { $0 = true }
      await store.receive(\.updateFetchAllQuery)
      try await store.state.$tagInfos.load()
      #expect(store.state.tagInfos.count == 6)
      $hideEmptyTags.withLock { $0 = true }
      await store.receive(\.updateFetchAllQuery)
      try await store.state.$tagInfos.load()
      #expect(store.state.tagInfos.count == 5)
      $hideBuiltinFonts.withLock { $0 = false }
      await store.receive(\.updateFetchAllQuery)
      try await store.state.$tagInfos.load()
      #expect(store.state.tagInfos.count == 6)
    }
  }

  @Test
  func tagsListView() async throws {
    withDependencies {
      $0.defaultDatabase = previewDatabase()
      $0.fileManager.fontFilePath = {
        SF2ResourceTag.rolandNicePiano.url.deletingLastPathComponent().appendingPathComponent($0, isDirectory: false)
      }
    } operation: {
      withSnapshotTesting(record: .failed) {
        TestSupport.assertSnapshot(matching: TagsListView.preview)
      }
    }
  }
}
