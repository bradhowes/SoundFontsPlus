import ComposableArchitecture
import TestSupport
import Dependencies
import DependenciesTestSupport
import Models
import SnapshotTesting
import Tagged
import Testing

@testable import SoundFonts

@Suite(
  .dependencies {
    $0.defaultDatabase = try appDatabase()
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

  @Test func initialize() async throws {
    let store = store()
    await store.send(.initialize)
    await store.receive(\.activeTagIdChanged, FontTag.Ubiquitous.all.id)

    store.exhaustivity = .off(showSkippedAssertions: false)
    await store.receive(\.soundFontInfosChanged)
    store.exhaustivity = .on

    #expect(store.state.rows.count == 4)

    await store.send(.deinitialize)
    await store.finish()
  }

  @Test func activeTagIdChanged() async throws {
    let store = store()
    await store.send(.initialize)
    await store.receive(\.activeTagIdChanged, FontTag.Ubiquitous.all.id)

    store.exhaustivity = .off(showSkippedAssertions: false)
    await store.receive(\.soundFontInfosChanged)
    store.exhaustivity = .on

    @Shared(.activeState) var activeState
    $activeState.withLock { $0.activeTagId = nil }

    await store.receive(\.activeTagIdChanged, -1)
    await store.receive(\.soundFontInfosChanged)

    $activeState.withLock { $0.activeTagId = FontTag.Ubiquitous.external.id }

    await store.receive(\.activeTagIdChanged, 4)
    await store.receive(\.soundFontInfosChanged) {
      $0.rows = []
    }

    await store.send(.deinitialize)
    await store.finish()
  }

  @Test func showActiveSoundFont() async throws {
    let store = store()
    await store.send(.initialize)
    await store.receive(\.activeTagIdChanged, FontTag.Ubiquitous.all.id)

    store.exhaustivity = .off(showSkippedAssertions: false)
    await store.receive(\.soundFontInfosChanged)
    store.exhaustivity = .on

    await store.send(.showActiveSoundFont)

    @Shared(.activeState) var activeState
    $activeState.withLock { $0.activeSoundFontId = nil }

    await store.send(.showActiveSoundFont)

    await store.send(.deinitialize)
    await store.finish()
  }

  @Test func selectSoundFont() async throws {
    @Shared(.selectedSoundFontId) var selectedSoundFontId
    #expect(selectedSoundFontId == nil)

    let store = store()
    await store.send(.initialize)
    await store.receive(\.activeTagIdChanged, FontTag.Ubiquitous.all.id)

    store.exhaustivity = .off(showSkippedAssertions: false)
    await store.receive(\.soundFontInfosChanged)
    store.exhaustivity = .on

    let row = store.state.rows[1]
    await store.send(.rows(.element(id: row.id, action: .delegate(.selectSoundFont(row.soundFontInfo)))))

    #expect(selectedSoundFontId == 2)

    await store.send(.deinitialize)
    await store.finish()
  }

  @Test func deleteSoundFont() async throws {
    let store = store()
    await store.send(.initialize)
    await store.receive(\.activeTagIdChanged, FontTag.Ubiquitous.all.id)

    store.exhaustivity = .off(showSkippedAssertions: false)
    await store.receive(\.soundFontInfosChanged)
    store.exhaustivity = .on

    var oldRows = store.state.rows
    let row = oldRows[1]
    await store.send(.rows(.element(id: row.id, action: .delegate(.deleteSoundFont(row.soundFontInfo)))))

    let deleted = oldRows.remove(id: row.id)
    #expect(deleted != nil)
    #expect(deleted?.soundFontInfo.displayName == "FreeFont")

    await store.receive(\.soundFontInfosChanged) {
      $0.rows = oldRows
    }

    await store.send(.deinitialize)
    await store.finish()
  }

  @Test func editSoundFont() async throws {
    let store = store()
    await store.send(.initialize)
    await store.receive(\.activeTagIdChanged, FontTag.Ubiquitous.all.id)

    store.exhaustivity = .off(showSkippedAssertions: false)
    await store.receive(\.soundFontInfosChanged)
    store.exhaustivity = .on

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

  @Test func soundFontsListViewPreview() async throws {
    try TestSupport.assertSnapshot(matching: SoundFontsListView.preview)
  }
}
