// Copyright © 2025 Brad Howes. All rights reserved.

import DependenciesTestSupport
import FeatureSupport
import SnapshotTesting
import Testing
import TestSupport

@testable import SoundFonts

@Suite(
  .dependencies {
    $0.defaultDatabase = TestSupport.testDatabase()
  },
  .snapshots(record: .failed)
)
@MainActor
struct SoundFontsListTests {

  func store() -> TestStoreOf<SoundFontsList> {
    @Shared(.activeState) var activeState = .default
    return TestStore(initialState: SoundFontsList.State()) {
      SoundFontsList()
    }
  }

  @Test
  func initialize() async throws {
    let store = store()
    await store.send(.initialize)
    await store.receive(\.activeTagIdChanged)

    await store.withExhaustivity(.off(showSkippedAssertions: false)) {
      await store.receive(\.soundFontInfosChanged)
    }

    #expect(store.state.rows.count == 2)

    await store.send(.deinitialize)
    await store.finish()
  }

  @Test
  func activeTagIdChanged() async throws {
    @Shared(.isAUv3) var isAUv3 = false
    let store = store()
    await store.send(.initialize)
    await store.receive(\.activeTagIdChanged)

    await store.withExhaustivity(.off(showSkippedAssertions: false)) {
      await store.receive(\.soundFontInfosChanged)
    }

    @Shared(.activeState) var activeState
    $activeState.withLock { $0.activeTagId = nil }

    await store.receive(\.activeTagIdChanged)
    await store.receive(\.soundFontInfosChanged)

    $activeState.withLock { $0.activeTagId = FontTag.Ubiquitous.external.id }

    await store.receive(\.activeTagIdChanged)
    await store.receive(\.soundFontInfosChanged) {
      $0.rows = []
    }

    await store.send(.deinitialize)
    await store.finish()
  }

  @Test
  func showActiveSoundFont() async throws {
    let store = store()
    await store.send(.initialize)
    await store.receive(\.activeTagIdChanged)

    await store.withExhaustivity(.off(showSkippedAssertions: false)) {
      await store.receive(\.soundFontInfosChanged)
    }

    await store.send(.showActiveSoundFont)

    @Shared(.activeState) var activeState
    $activeState.withLock { $0.activeSoundFontId = nil }

    await store.send(.showActiveSoundFont)

    await store.send(.deinitialize)
    await store.finish()
  }

  @Test
  func selectSoundFont() async throws {
    @Shared(.selectedSoundFontId) var selectedSoundFontId
    #expect(selectedSoundFontId == nil)

    let store = store()
    await store.send(.initialize)
    await store.receive(\.activeTagIdChanged)

    await store.withExhaustivity(.off(showSkippedAssertions: false)) {
      await store.receive(\.soundFontInfosChanged)
    }

    let row = store.state.rows[1]
    await store.send(.rows(.element(id: row.id, action: .delegate(.selectSoundFont(row.soundFontInfo)))))

    #expect(selectedSoundFontId == 2)

    await store.send(.deinitialize)
    await store.finish()
  }

  @Test
  func deleteSoundFontCancelled() async throws {
    let store = store()
    await store.send(.initialize)
    await store.receive(\.activeTagIdChanged)

    await store.withExhaustivity(.off(showSkippedAssertions: false)) {
      await store.receive(\.soundFontInfosChanged)
    }

    let row = store.state.rows[1]
    await store.send(.rows(.element(id: row.id, action: .delegate(.deleteSoundFont(row.soundFontInfo))))) {
      $0.destination = .alert(.confirmDeleteSoundFont(action: .deleteSoundFontConfirmed(row.soundFontInfo),
                                                      displayName: "Font 2"))
    }

    await store.send(.destination(.dismiss)) {
      $0.destination = nil
    }

    await store.send(.deinitialize)
    await store.finish()
  }

  @Test
  func deleteSoundFontConfirmed() async throws {
    let store = store()
    await store.send(.initialize)
    await store.receive(\.activeTagIdChanged)

    await store.withExhaustivity(.off(showSkippedAssertions: false)) {
      await store.receive(\.soundFontInfosChanged)
    }

    var oldRows = store.state.rows
    let row = oldRows[1]
    await store.send(.rows(.element(id: row.id, action: .delegate(.deleteSoundFont(row.soundFontInfo))))) {
      $0.destination = .alert(.confirmDeleteSoundFont(action: .deleteSoundFontConfirmed(row.soundFontInfo),
                                                      displayName: "Font 2"))
    }

    await store.send(.destination(.presented(.alert(.deleteSoundFontConfirmed(row.soundFontInfo))))) {
      $0.destination = nil
    }

    let deleted = oldRows.remove(id: row.id)
    #expect(deleted != nil)
    #expect(deleted?.soundFontInfo.displayName == "Font 2")

    await store.receive(\.soundFontInfosChanged) {
      $0.rows = oldRows
    }

    await store.send(.deinitialize)
    await store.finish()
  }

  @Test
  func editSoundFont() async throws {
    let store = store()
    await store.send(.initialize)
    await store.receive(\.activeTagIdChanged)

    await store.withExhaustivity(.off(showSkippedAssertions: false)) {
      await store.receive(\.soundFontInfosChanged)
    }

    let row = store.state.rows.first!
    await store.send(.rows(.element(id: row.id, action: .delegate(.editSoundFont(row.soundFontInfo)))))

    let soundFontId = row.soundFontInfo.id
    @Dependency(\.defaultDatabase) var database
    let soundFont = try? await database.read({ db in
      return try SoundFont.all.find(soundFontId).fetchOne(db)
    })

    await store.receive(\.delegate, .edit(soundFont!))

    await store.send(.deinitialize)
    await store.finish()
  }

  @Test
  func soundFontsListViewPreview() async throws {
    try TestSupport.assertSnapshot(matching: SoundFontsListView.preview)
  }
}
