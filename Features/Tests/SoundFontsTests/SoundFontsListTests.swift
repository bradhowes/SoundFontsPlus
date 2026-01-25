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
    $0.fileManager.fontFilePath = { FileManager.default.temporaryDirectory.appendingPathComponent($0) }
    $0.fileManager.removeItem = { _ in }
    $0.fileManager.fileExists = { _ in false }
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
  func deleteModeDeleteButtonTapped() async throws {
    try await initialized { store in

      await store.send(\.headerDoubleTapped) {
        $0.editingMode = .active
      }
      await store.send(\.deleteModeCancelButtonTapped) {
        $0.editingMode = .inactive
      }
    }
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
  func deleteSoundFontBuiltinConfirmed() async throws {
    try await initialized { store in
      let row = store.state.rows[1]

      await store.send(.rows(.element(id: row.id, action: .delegate(.deleteSoundFont(row.soundFontInfo))))) {
        $0.destination = .alert(.confirmDeleteSoundFont(action: .deleteSoundFontConfirmed(row.soundFontInfo),
                                                        displayName: "Font 2"))
      }

      await store.send(.destination(.presented(.alert(.deleteSoundFontConfirmed(row.soundFontInfo))))) {
        $0.destination = .alert(.genericDeleteFailure("Cannot delete built-in sound fonts."))
      }
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
    @Shared(.activeState) var activeState
    @Shared(.selectedSoundFontId) var selectedSoundFontId

    try await initialized { store in

      var oldRows = store.state.rows
      let row = oldRows[2]

      $activeState.withLock { $0.activeSoundFontId = row.id }
      $selectedSoundFontId.withLock { $0 = row.id }

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

      #expect(activeState.activeSoundFontId == nil)
      #expect(selectedSoundFontId == nil)
    }
  }

  @Test
  func deleteSoundFontConfirmedInvalidSoundFontId() async throws {
    try await initialized { store in
      let row = store.state.rows[0]
      let bad: SoundFontInfo = .init(
        id: 999,
        displayName: row.soundFontInfo.displayName + " Bogus",
        kind: row.soundFontInfo.kind,
        location: row.soundFontInfo.location
      )

      await store.send(.rows(.element(id: row.id, action: .delegate(.deleteSoundFont(bad))))) {
        $0.destination = .alert(.confirmDeleteSoundFont(action: .deleteSoundFontConfirmed(bad),
                                                        displayName: "Font 1 Bogus"))
      }

      await store.send(.destination(.presented(.alert(.deleteSoundFontConfirmed(bad))))) {
        $0.destination = .alert(.genericDeleteFailure("Sound font ID 999 was not found."))
      }
    }
  }

  @Test
  func deleteSoundFontConfirmedBuiltinFailed() async throws {
    try await initialized { store in
      let row = store.state.rows[0]
      await store.send(.rows(.element(id: row.id, action: .delegate(.deleteSoundFont(row.soundFontInfo))))) {
        $0.destination = .alert(.confirmDeleteSoundFont(action: .deleteSoundFontConfirmed(row.soundFontInfo),
                                                        displayName: "Font 1"))
      }

      await store.send(.destination(.presented(.alert(.deleteSoundFontConfirmed(row.soundFontInfo))))) {
        $0.destination = .alert(.genericDeleteFailure("Cannot delete built-in sound fonts."))
      }
    }
  }

  @Test(
    .dependencies {
      @Shared(.inMemory("removeLog")) var removeLog = RemoveLog()
      $0.fileManager.fontFilePath = { what in URL(filePath: "/fake/path").appendingPathComponent(what) }
      $0.fileManager.removeItem = { _ in throw NSError(domain: "bogus", code: 1, userInfo: nil) }
      $0.fileManager.fileExists = { _ in true }
    }
  )
  func deleteSoundFontConfirmedInternalFailedRemove() async throws {
    @Shared(.inMemory("removeLog")) var removeLog = RemoveLog()
    try await initialized { store in

      var oldRows = store.state.rows
      let row = oldRows[2]
      await store.send(.rows(.element(id: row.id, action: .delegate(.deleteSoundFont(row.soundFontInfo))))) {
        $0.destination = .alert(.confirmDeleteSoundFont(action: .deleteSoundFontConfirmed(row.soundFontInfo),
                                                        displayName: "Font 3"))
      }

      await store.send(.destination(.presented(.alert(.deleteSoundFontConfirmed(row.soundFontInfo))))) {
        $0.destination = .alert(.genericDeleteFailure("Failed to remove sound font file GeneralUser GS MuseScore v1.442.sf2."))
      }

      let deleted = oldRows.remove(id: row.id)
      #expect(deleted != nil)
      #expect(deleted?.soundFontInfo.displayName == "Font 3")

      await store.receive(\.rowsUpdated) {
        $0.rows = oldRows
      }

      #expect(removeLog.log.isEmpty)
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
  func deleteModeCancel() async throws {
    try await initialized { store in

      await store.send(\.headerDoubleTapped) {
        $0.editingMode = .active
      }

      await store.send(.rows(.element(id: 4, action: .toggleDeleting))) {
        $0.rows[3].deleting = true
      }

      await store.send(\.deleteModeCancelButtonTapped) {
        $0.editingMode = .inactive
      }

      await store.send(\.headerDoubleTapped) {
        $0.editingMode = .active
        $0.rows[3].deleting = false
      }
    }
  }

  @Test
  func deleteModeConfirmEmpty() async throws {
    try await initialized { store in

      await store.send(\.headerDoubleTapped) {
        $0.editingMode = .active
      }

      await store.send(\.deleteModeDeleteButtonTapped) {
        $0.editingMode = .inactive
      }
    }
  }

  @Test
  func deleteModeConfirm() async throws {
    try await initialized { store in

      await store.send(\.headerDoubleTapped) {
        $0.editingMode = .active
      }

      var rows = store.state.rows
      let idx3 = store.state.rows.index(id: 3)!
      let idx4 = store.state.rows.index(id: 4)!

      await store.send(.rows(.element(id: 3, action: .toggleDeleting))) {
        $0.rows[idx3].deleting = true
      }

      await store.send(.rows(.element(id: 4, action: .toggleDeleting))) {
        $0.rows[idx4].deleting = true
      }

      let selected = store.state.rows.filter(\.deleting).map(\.soundFontInfo)

      await store.send(\.deleteModeDeleteButtonTapped) {
        $0.destination = .alert(
          .confirmDeleteSoundFontCollection(
            action: .deleteSoundFontCollectionConfirmed(selected),
            count: selected.count
          )
        )
      }

      await store.send(\.destination.presented.alert.deleteSoundFontCollectionConfirmed, selected) {
        $0.editingMode = .inactive
        $0.destination = nil
      }

      rows.remove(id: 3)
      await store.receive(\.rowsUpdated) {
        $0.rows = rows
      }

      rows.remove(id: 4)
      await store.receive(\.rowsUpdated) {
        $0.rows = rows
      }
    }
  }

  @Test
  func soundFontsListViewPreview() async throws {
    try TestSupport.assertSnapshot(matching: SoundFontsListView.preview)
  }
}
