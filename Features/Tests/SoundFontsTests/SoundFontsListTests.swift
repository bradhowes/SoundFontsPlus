// Copyright © 2025 Brad Howes. All rights reserved.

import DependenciesTestSupport
import FeatureSupport
import SnapshotTesting
import SQLiteData
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
  @Shared(.hideBuiltinFonts) var hideBuiltinFonts = false
  @Shared(.hideEmptyTags) var hideEmptyTags = false

  init() {
    $hideBuiltinFonts.withLock { $0 = false }
    $hideEmptyTags.withLock { $0 = false }
  }

  func store() -> TestStoreOf<SoundFontsList> {
    return TestStore(initialState: SoundFontsList.State()) {
      SoundFontsList()
    }
  }

  func initialized(_ closure: (TestStoreOf<SoundFontsList>) async throws -> Void) async throws {
    let store = store()
    await store.send(.initialize)

    #expect(store.state.rows.count == 4)

    await store.receive(\.rowsSourceUpdated)

    try await closure(store)

    await store.send(.deinitialize)
    await store.finish()
  }

  @Test
  func initialize() async throws {
    try await initialized { _ in }
  }

  @Test
  func alertInvalidBookmark() async throws {
    try await initialized { store in
      let info = store.state.rows[id: 3]!.soundFontInfo
      await store.send(\.rows[id: 3].delegate.alertInvalidBookmark, info) {
        $0.destination = .alert(.invalidBookmark(displayName: info.displayName))
      }
    }
  }

  @Test
  func alertMissingFile() async throws {
    try await initialized { store in
      let info = store.state.rows[id: 3]!.soundFontInfo
      await store.send(\.rows[id: 3].delegate.alertMissingFile, info) {
        $0.destination = .alert(.missingFile(displayName: info.displayName))
      }
    }
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

    try await initialized { store in
      await store.send(\.activeTagIdChanged, Tag.Ubiquitous.all.id)
      await store.receive(\.rowsSourceUpdated)
      await store.send(\.activeTagIdChanged, Tag.Ubiquitous.external.id) {
        $0.activeTagId = -5
      }
      await store.withExhaustivity(.off(showSkippedAssertions: false)) {
        await store.receive(\.rowsSourceUpdated)
      }
      #expect(store.state.rows.count == 1)
    }
  }

  @Test
  func showActiveSoundFont() async throws {
    try await initialized { store in
      await store.send(.showActiveSoundFont)
      await store.send(.showActiveSoundFont)
    }
  }

  @Test
  func selectSoundFont() async throws {
    try await initialized { store in

      var row = store.state.rows[1]
      await store.send(.rows(.element(id: row.id, action: .delegate(.select(row.soundFontInfo, available: true))))) {
        $0.selectedPresetSource = .selected(2)
      }

      await store.receive(\.delegate.presetSourceChanged, .selected(2))

      row = store.state.rows[0]
      await store.send(.rows(.element(id: row.id, action: .delegate(.select(row.soundFontInfo, available: false))))) {
        $0.selectedPresetSource = .selected(1)
      }

      await store.receive(\.delegate.presetSourceChanged, nil)
    }
  }

  @Test
  func deleteSoundFontCancelled() async throws {
    try await initialized { store in

      let row = store.state.rows[1]
      await store.send(.rows(.element(id: row.id, action: .delegate(.delete(row.soundFontInfo))))) {
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

      await store.send(.rows(.element(id: row.id, action: .delegate(.delete(row.soundFontInfo))))) {
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

    try await initialized { store in

      var oldRows = store.state.rows
      let row = oldRows[2]

      await store.send(.rows(.element(id: row.id, action: .delegate(.delete(row.soundFontInfo))))) {
        $0.destination = .alert(.confirmDeleteSoundFont(action: .deleteSoundFontConfirmed(row.soundFontInfo),
                                                        displayName: "Font 3"))
      }

      let deleted = oldRows.remove(id: row.id)
      await store.send(.destination(.presented(.alert(.deleteSoundFontConfirmed(row.soundFontInfo))))) {
        $0.destination = nil
        $0.rows.removeAll(where: {$0.id == row.id})
      }

      await store.receive(\.rowsSourceUpdated)

      #expect(deleted != nil)
      #expect(deleted?.soundFontInfo.displayName == "Font 3")

      #expect(removeLog.log.count == 1)
      #expect(removeLog.log[0] == URL(filePath: "/fake/path/GeneralUser GS MuseScore v1.442.sf2"))

      #expect(store.state.activePresetSource == nil)
      #expect(store.state.selectedPresetSource == nil)
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

      await store.send(.rows(.element(id: row.id, action: .delegate(.delete(bad))))) {
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
      await store.send(.rows(.element(id: row.id, action: .delegate(.delete(row.soundFontInfo))))) {
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
      await store.send(.rows(.element(id: row.id, action: .delegate(.delete(row.soundFontInfo))))) {
        $0.destination = .alert(.confirmDeleteSoundFont(action: .deleteSoundFontConfirmed(row.soundFontInfo),
                                                        displayName: "Font 3"))
      }

      await store.send(.destination(.presented(.alert(.deleteSoundFontConfirmed(row.soundFontInfo))))) {
        $0.destination = .alert(.genericDeleteFailure("Failed to remove sound font file GeneralUser GS MuseScore v1.442.sf2."))
        $0.rows.removeAll(where: {$0.id == row.id})
      }

      await store.receive(\.rowsSourceUpdated)

      let deleted = oldRows.remove(id: row.id)
      #expect(deleted != nil)
      #expect(deleted?.soundFontInfo.displayName == "Font 3")

      #expect(removeLog.log.isEmpty)
    }
  }

  @Test
  func deleteSoundFontConfirmedExternal() async throws {
    try await initialized { store in

      var oldRows = store.state.rows
      let row = oldRows[3]
      await store.send(.rows(.element(id: row.id, action: .delegate(.delete(row.soundFontInfo))))) {
        $0.destination = .alert(.confirmDeleteSoundFont(action: .deleteSoundFontConfirmed(row.soundFontInfo),
                                                        displayName: "Font 4"))
      }

      await store.send(.destination(.presented(.alert(.deleteSoundFontConfirmed(row.soundFontInfo))))) {
        $0.destination = nil
        $0.rows.removeAll(where: {$0.id == row.id})
      }

      await store.receive(\.rowsSourceUpdated)

      let deleted = oldRows.remove(id: row.id)
      #expect(deleted != nil)
      #expect(deleted?.soundFontInfo.displayName == "Font 4")
    }
  }

  @Test
  func editSoundFont() async throws {
    try await initialized { store in

      let row = store.state.rows.first!
      await store.send(.rows(.element(id: row.id, action: .delegate(.edit(row.soundFontInfo)))))

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
        $0.rows.removeAll(where: {$0.id == 3 || $0.id == 4})
        $0.destination = nil
      }

      await store.receive(\.rowsSourceUpdated)
    }
  }

  @Test
  func searchSoundFonts() async throws {
    try await initialized { store in

      let rows = store.state.rows

      await store.send(\.searchButtonTapped) {
        $0.isSearchFieldPresented = true
        $0.focusedField = .searchText
        $0.searchSource = rows
        $0.rows = []
      }

      await store.send(.searchTextChanged("no")) {
        $0.searchText = "no"
      }

      await store.send(.clearSearchTextField) {
        $0.searchText = ""
        $0.rows = []
      }

      await store.send(.cancelSearchButtonTapped) {
        $0.searchSource = []
        $0.isSearchFieldPresented = false
        $0.focusedField = nil
        $0.lastSearchText = ""
        $0.rows = rows
      }
    }
  }

  @Test(
    .dependencies {
      $0.defaultDatabase = try! appDatabase()
    }
  )
  func selectFromSearch() async throws {
    try await initialized { store in

      let rows = store.state.rows
      print(rows.map(\.soundFontInfo.displayName))
      let land = rows.filter({ $0.soundFontInfo.displayName.contains("land") })[0]

      await store.send(\.searchButtonTapped) {
        $0.isSearchFieldPresented = true
        $0.focusedField = .searchText
        $0.searchSource = rows
        $0.rows = []
      }

      await store.send(.searchTextChanged("land")) {
        $0.searchText = "land"
        $0.rows = [land]
      }

      await store.send(\.rows[id: 4].delegate, .select(land.soundFontInfo, available: true)) {
        $0.selectedPresetSource = .selected(4)
      }

      await store.receive(\.delegate.presetSourceChanged, .selected(4))

      await store.send(\.cancelSearchButtonTapped) {
        $0.rows = rows
        $0.searchSource = []
        $0.isSearchFieldPresented = false
        $0.lastSearchText = "land"
        $0.searchText = ""
        $0.focusedField = nil
      }
    }
  }

  @Test
  func soundFontsListViewPreview() async throws {
    withDependencies {
      $0.defaultDatabase = previewDatabase()
      $0.fileManager.fontFilePath = {
        SF2ResourceTag.rolandNicePiano.url.deletingLastPathComponent().appendingPathComponent($0, isDirectory: false)
      }
    } operation: {
      withSnapshotTesting(record: .failed) {
        TestSupport.assertSnapshot(matching: SoundFontsListView.preview)
      }
    }
  }
}
