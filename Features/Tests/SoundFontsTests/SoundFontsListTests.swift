// Copyright © 2025 Brad Howes. All rights reserved.

import DependenciesTestSupport
import FeatureSupport
import SnapshotTesting
import Testing
import TestSupport

@testable import SoundFonts

private class RemoveLog: @unchecked Sendable {
  var log: [URL] = []
  func removeItem(_ url: URL) throws {
    log.append(url)
  }
}

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

  func initialized(_ closure: (TestStoreOf<SoundFontsList>) async throws -> Void) async throws {
    @Shared(.hideBuiltinFonts) var hideBuiltinFonts = false
    @Shared(.hideEmptyTags) var hideEmptyTags = false

    let store = store()
    await store.send(.initialize)
    await store.receive(\.updateFetchAllQuery)

    await store.withExhaustivity(.off(showSkippedAssertions: false)) {
      await store.receive(\.rowsUpdated)
    }

    #expect(store.state.rows.count == 4)

    try await closure(store)

    await store.send(.deinitialize)
    await store.finish()
  }

  @Test
  func initialize() async throws {
    try await initialized { _ in }
  }

  @Test
  func activeTagIdChanged() async throws {
    @Shared(.isAUv3) var isAUv3 = false

    try await initialized { store in
      @Shared(.activeState) var activeState
      $activeState.withLock { $0.activeTagId = nil }

      await store.receive(\.updateFetchAllQuery)
      await store.receive(\.rowsUpdated)

      $activeState.withLock { $0.activeTagId = Tag.Ubiquitous.external.id }

      await store.receive(\.updateFetchAllQuery)
      await store.withExhaustivity(.off(showSkippedAssertions: false)) {
        await store.receive(\.rowsUpdated)
      }
      #expect(store.state.rows.count == 1)
    }
  }

  @Test
  func showActiveSoundFont() async throws {
    try await initialized { store in
      await store.send(.showActiveSoundFont)

      @Shared(.activeState) var activeState
      $activeState.withLock { $0.activeSoundFontId = nil }

      await store.send(.showActiveSoundFont)
    }
  }

  @Test
  func selectSoundFont() async throws {
    @Shared(.selectedSoundFontId) var selectedSoundFontId
    #expect(selectedSoundFontId == nil)

    try await initialized { store in

      var row = store.state.rows[1]
      await store.send(.rows(.element(id: row.id, action: .delegate(.selectSoundFont(row.soundFontInfo, available: true)))))

      #expect(selectedSoundFontId == 2)

      row = store.state.rows[0]
      await store.send(.rows(.element(id: row.id, action: .delegate(.selectSoundFont(row.soundFontInfo, available: false)))))

      #expect(selectedSoundFontId == 2)
    }
  }

  @Test
  func deleteSoundFontCancelled() async throws {
    try await initialized { store in

      let row = store.state.rows[1]
      await store.send(.rows(.element(id: row.id, action: .delegate(.deleteSoundFont(row.soundFontInfo))))) {
        $0.destination = .alert(.confirmDeleteSoundFont(action: .deleteSoundFontConfirmed(row.soundFontInfo),
                                                        displayName: "Font 2"))
      }

      await store.send(.destination(.dismiss)) {
        $0.destination = nil
      }
    }
  }

  @Test
  func deleteSoundFontConfirmed() async throws {
    try await initialized { store in

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
    }
  }

  @Test(
    .dependencies {
      @Shared(.inMemory("removeLog")) var removeLog = RemoveLog()
      $0.fileManager.fontFilePath = { what in URL(filePath: "/fake/path").appendingPathComponent(what) }
      $0.fileManager.removeItem = removeLog.removeItem
    }
  )
  func deleteSoundFontConfirmedInternal() async throws {
    @Shared(.inMemory("removeLog")) var removeLog = RemoveLog()
    try await initialized { store in

      var oldRows = store.state.rows
      let row = oldRows[2]
      await store.send(.rows(.element(id: row.id, action: .delegate(.deleteSoundFont(row.soundFontInfo))))) {
        $0.destination = .alert(.confirmDeleteSoundFont(action: .deleteSoundFontConfirmed(row.soundFontInfo),
                                                        displayName: "Font 3"))
      }

      await store.send(.destination(.presented(.alert(.deleteSoundFontConfirmed(row.soundFontInfo))))) {
        $0.destination = nil
      }

      let deleted = oldRows.remove(id: row.id)
      #expect(deleted != nil)
      #expect(deleted?.soundFontInfo.displayName == "Font 3")

      await store.receive(\.rowsUpdated) {
        $0.rows = oldRows
      }
      #expect(removeLog.log.count == 1)
      #expect(removeLog.log[0] == URL(filePath: "/fake/path/GeneralUser GS MuseScore v1.442.sf2"))
    }
  }

  @Test
  func deleteSoundFontConfirmedExternal() async throws {
    try await initialized { store in

      var oldRows = store.state.rows
      let row = oldRows[3]
      await store.send(.rows(.element(id: row.id, action: .delegate(.deleteSoundFont(row.soundFontInfo))))) {
        $0.destination = .alert(.confirmDeleteSoundFont(action: .deleteSoundFontConfirmed(row.soundFontInfo),
                                                        displayName: "Font 4"))
      }

      await store.send(.destination(.presented(.alert(.deleteSoundFontConfirmed(row.soundFontInfo))))) {
        $0.destination = nil
      }

      let deleted = oldRows.remove(id: row.id)
      #expect(deleted != nil)
      #expect(deleted?.soundFontInfo.displayName == "Font 4")

      await store.receive(\.rowsUpdated) {
        $0.rows = oldRows
      }
    }
  }

  @Test
  func editSoundFont() async throws {
    try await initialized { store in

      let row = store.state.rows.first!
      await store.send(.rows(.element(id: row.id, action: .delegate(.editSoundFont(row.soundFontInfo)))))

      let soundFontId = row.soundFontInfo.id
      @Dependency(\.defaultDatabase) var database
      let soundFont = try? await database.read({ db in
        return try SoundFont.all.find(soundFontId).fetchOne(db)
      })

      await store.receive(\.delegate, .edit(soundFont!))
    }
  }

  @Test
  func soundFontsListViewPreview() async throws {
    try TestSupport.assertSnapshot(matching: SoundFontsListView.preview)
  }
}
