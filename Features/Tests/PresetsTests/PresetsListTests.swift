// Copyright © 2025 Brad Howes. All rights reserved.

import DependenciesTestSupport
import FeatureSupport
import SnapshotTesting
import Testing
import TestSupport

@testable import Presets

@Suite(
  .dependencies {
    $0.defaultDatabase = TestSupport.testDatabase()
    $0.continuousClock = TestClock()
  },
  //  .snapshots(record: .failed)
)
@MainActor
struct PresetsListTests {

  @Shared(.showOnlyFavorites) var showOnlyFavorites = false
  @Shared(.favoritesOnTop) var favoritesOnTop = false
  @Shared(.sortPresetsByName) var sortPresetsByName = false
  @Shared(.confirmPresetHiding) var confirmPresetHiding = true

  init() {
    $showOnlyFavorites.withLock { $0 = false }
    $favoritesOnTop.withLock { $0 = false }
    $sortPresetsByName.withLock { $0 = false }
  }

  static func makePresets(_ pairs: [(Int, String)]) -> [Preset] {
    pairs.map { index, name in
      Preset(
        id: .init(rawValue: Int64(index + 1)),
        index: index,
        bank: 0,
        program: index,
        originalName: "Original Preset \(index + 1)",
        soundFontId: 1,
        displayName: name,
        notes: "",
        kind: index == 2 ? .hidden : .preset
      )
    }
  }

  func setup(
    activeSoundFontId: SoundFont.ID? = 1,
    selectedSoundFontId: SoundFont.ID? = 2,
    searchText: String? = nil,
    editingVisibility: Bool = false
  ) throws -> TestStoreOf<PresetsList> {
    let store = TestStore(
      initialState: PresetsList.State(
        presetSource: activeSoundFontId.flatMap { .active($0) } ?? selectedSoundFontId.flatMap { .selected($0) },
        searchText: searchText,
        editingVisibility: editingVisibility
      )
    ) {
      PresetsList()
    }

    return store
  }

  func initialized(_ closure: (TestStoreOf<PresetsList>, [Preset]) async throws -> Void) async throws {
    let store = try setup()
    await store.send(.presetSourceChanged(.active(1)))
    let presets = Preset.visible(for: 1)

    #expect(!presets.isEmpty)

    await store.receive(.rowsUpdated(presets: presets, showActive: true))

    try await closure(store, presets)

    await store.send(.deinitialize)
    await store.finish()
  }

  @Test
  func initializeWithNoSoundFontId() async throws {
    let store = try setup(activeSoundFontId: nil, selectedSoundFontId: nil)

    await store.send(.presetSourceChanged(nil))
    #expect(store.state.sections.count == 1)

    await store.receive(.rowsUpdated(presets: [], showActive: true))

    await store.send(.deinitialize)
    await store.finish()
  }

  @Test
  func initializeWithSoundFontId() async throws {
    try await initialized { _, _ in }
  }

  @Test
  func presetSourceChangedFetches() async throws {
    try await initialized { store, presets in
      await store.send(.presetSourceChanged(.active(2))) {
        $0.presetSource = .active(2)
      }
      let presets = Preset.visible(for: 2)
      await store.receive(.rowsUpdated(presets: presets, showActive: true)) {
        $0.presets = presets
        $0.sections = [
          .init(
            section: 0,
            sectionText: "Presets",
            sectionIndex: "0",
            presets: presets[...],
            presetSource: .active(2)
          )
        ]
      }
    }
  }

  @Test
  func clearScrollTo() async throws {
    try await initialized { store, _ in
      await store.send(\.clearScrollToTarget)
    }
  }

  @Test(
    .dependencies {
      $0.defaultDatabase = try! appDatabase(fonts: [.fluidFont], loadAllPresets: true)
    }
  )
  func searchPresets() async throws {
    @Dependency(\.continuousClock) var clock
    try await initialized { store, presets in
      await store.send(\.sections, .element(id: 0, action: .delegate(.searchButtonTapped))) {
        $0.scrollToTarget = nil
        $0.sections = [
          .init(
            section: 0,
            sectionText: "Found 0",
            sectionIndex: "",
            presets: [],
            presetSource: nil
          )
        ]
        $0.isSearchFieldPresented = true
        $0.focusedField = .searchText
      }

      await store.send(.searchTextChanged("arp")) {
        $0.searchText = "arp"
        $0.sections = [
          .init(
            section: 0,
            sectionText: "Found 3",
            sectionIndex: "0",
            presets: presets.filter({$0.displayName.contains("arp")})[...],
            presetSource: .active(1)
          )
        ]
      }

      await store.send(.clearSearchTextField) {
        $0.searchText = ""
        $0.sections = [
          .init(
            section: 0,
            sectionText: "Found 0",
            sectionIndex: "",
            presets: [],
            presetSource: nil
          )
        ]
      }

      await store.send(.cancelSearchButtonTapped) {
        $0.isSearchFieldPresented = false
        $0.focusedField = nil
        $0.presets = Preset.visible(for: 1)
        $0.sections = group(Preset.visible(for: 1), presetSource: .active(1), activePresetId: nil, searching: false)
      }
    }
  }

  @Test(
    .dependencies {
      $0.defaultDatabase = try! appDatabase(fonts: [.fluidFont], loadAllPresets: true)
      $0.fileManager = .liveValue
    }
  )
  func selectFromSearch() async throws {
    @Dependency(\.continuousClock) var clock
    try await initialized { store, presets in
      await store.send(\.sections, .element(id: 0, action: .delegate(.searchButtonTapped))) {
        $0.scrollToTarget = nil
        $0.sections = [
          .init(
            section: 0,
            sectionText: "Found 0",
            sectionIndex: "",
            presets: [],
            presetSource: nil
          )
        ]
        $0.isSearchFieldPresented = true
        $0.focusedField = .searchText
      }

      await store.send(.searchTextChanged("arp")) {
        $0.searchText = "arp"
        $0.sections = [
          .init(
            section: 0,
            sectionText: "Found 3",
            sectionIndex: "0",
            presets: presets.filter({$0.displayName.contains("arp")})[...],
            presetSource: .active(1)
          )
        ]
      }

      let preset = store.state.sections[0].rows[0].preset

      await store.send(
        \.sections,
         .element(
          id: 0,
          action: .rows(.element(id: preset.id, action: .delegate(.selectPreset(preset))))
         )
      ) {
        $0.sections[0].presetSource = .active(1)
        $0.sections[0].activePresetId = 7
      }

      await store.receive(\.sections[id: 0].delegate.selectPreset) {
        $0.activePresetId = 7
      }

      await store.receive(\.delegate.activePresetIdChanged, 7)
    }
  }

  @Test
  func detectSoundFontIdChange() async throws {
    try await initialized { store, presets in

      await store.send(.presetSourceChanged(.selected(2))) {
        $0.presetSource = .selected(2)
      }

      let presets = Preset.visible(for: 2)
      await store.receive(.rowsUpdated(presets: presets, showActive: true)) {
        $0.presets = presets
        $0.sections = [
          .init(
            section: 0,
            sectionText: "Presets",
            sectionIndex: "0",
            presets: presets[...],
            presetSource: .selected(2)
          )
        ]
      }
    }
  }

  @Test(
    .dependencies {
      $0.fileManager.fileExists = { _ in true }
    }
  )
  func buttonTapped() async throws {
    try await initialized { store, presets in
      await store.send(
        \.sections,
         .element(
          id: store.state.sections[0].id,
          action: .rows(.element(id: presets[1].id, action: .delegate(.selectPreset(presets[1]))))
         )
      ) {
        $0.sections[0].activePresetId = 2
      }
      await store.receive(\.sections[id: store.state.sections[0].id].delegate.selectPreset, presets[1]) {
        $0.activePresetId = 2
      }
      await store.receive(\.delegate.activePresetIdChanged, 2)
    }
  }

  @Test(
    .dependencies {
      $0.fileManager.fileExists = { _ in false }
    }
  )
  func buttonTappedMissingFile() async throws {
    try await initialized { store, presets in
      await store.send(
        \.sections,
         .element(
          id: store.state.sections[0].id,
          action: .rows(.element(id: presets[1].id, action: .delegate(.selectPreset(presets[1]))))
         )
      ) {
        $0.sections[0].activePresetId = 2
      }
      await store.receive(\.sections[id: store.state.sections[0].id].delegate.selectPreset, presets[1]) {
        $0.destination = .alert(.missingFileForSelectedPreset(action: .missingFileForSelectedPreset(1), displayName: "Font 1"))
      }
    }
  }

  @Test
  func deleteFavoriteCancel() async throws {
    @Dependency(\.continuousClock) var clock
    let testClock = clock as! TestClock<Duration>

    try await initialized { store, presets in

      await store.send(
        \.sections,
         .element(
          id: store.state.sections[0].id,
          action: .rows(.element(id: presets[0].id, action: .delegate(.createFavorite(presets[0]))))
         )
      )

      await store.receive(\.sections[id: store.state.sections[0].id].delegate.createFavorite, presets[0])
      await store.receive(\.showPresetDelayed, 13)

      let presets = Preset.visible(for: 1)
      await store.receive(.rowsUpdated(presets: presets, showActive: false)) {
        $0.presets = presets
        $0.sections = [
          .init(
            section: 0,
            sectionText: "Presets",
            sectionIndex: "0",
            presets: presets[...],
            presetSource: .active(1)
          )
        ]
      }

      let favoriteIndex = 1
      var updated = Preset.visible(for: 1)
      #expect(updated[favoriteIndex].kind == .favorite)

      await testClock.advance(by: PresetsList.delayBeforeShowingActivePreset)

      await store.receive(\.showPresetNow, 13) { $0.scrollToTarget = .preset(13) }

      await store.send(
        \.sections,
         .element(
          id: store.state.sections[0].id,
          action: .rows(.element(id: updated[favoriteIndex].id, action: .delegate(.deleteFavorite(updated[favoriteIndex]))))
         )
      )

      await store.receive(\.sections[id: store.state.sections[0].id].delegate.deleteFavorite, updated[favoriteIndex]) {
        $0.destination = .alert(
          AlertState.confirmDeleteFavorite(
            action: .deleteFavoriteConfirmed(updated[1]),
            displayName: updated[1].displayName
          )
        )
      }

      await store.send(.destination(.dismiss)) { $0.destination = nil }

      updated = Preset.visible(for: 1)
      #expect(updated[favoriteIndex].kind == .favorite)
    }
  }

  @Test
  func deleteFavoriteConfirm() async throws {
    @Dependency(\.continuousClock) var clock
    let testClock = clock as! TestClock<Duration>

    try await initialized { store, presets in

      await store.send(
        \.sections,
         .element(
          id: store.state.sections[0].id,
          action: .rows(.element(id: presets[0].id, action: .delegate(.createFavorite(presets[0]))))
         )
      )

      await store.receive(\.sections[id: store.state.sections[0].id].delegate.createFavorite, presets[0])

      await store.receive(\.showPresetDelayed, 13)

      let presets = Preset.visible(for: 1)
      for p in presets {
        print("--", p)
      }

      await store.receive(.rowsUpdated(presets: presets, showActive: false)) {
        $0.presets = presets
        $0.sections = [
          .init(
            section: 0,
            sectionText: "Presets",
            sectionIndex: "0",
            presets: presets[...],
            presetSource: .active(1)
          )
        ]
      }

      let favoriteIndex = 1
      var updated = Preset.visible(for: 1)
      for p in presets {
        print("--", p)
      }

      #expect(updated[favoriteIndex].kind == .favorite)

      await testClock.advance(by: PresetsList.delayBeforeShowingActivePreset)

      await store.receive(\.showPresetNow, 13) {
        $0.scrollToTarget = .preset(13)
      }

      await store.send(
        \.sections,
         .element(
          id: store.state.sections[0].id,
          action: .rows(.element(id: updated[favoriteIndex].id, action: .delegate(.deleteFavorite(updated[favoriteIndex]))))
         )
      )

      await store.receive(\.sections[id: store.state.sections[0].id].delegate.deleteFavorite, updated[favoriteIndex]) {
        $0.destination = .alert(
          AlertState.confirmDeleteFavorite(
            action: .deleteFavoriteConfirmed(updated[1]),
            displayName: updated[1].displayName
          )
        )
      }

      await store.send(\.destination.presented.alert.deleteFavoriteConfirmed, updated[favoriteIndex]) {
        $0.destination = nil
      }

      updated = Preset.visible(for: 1)
      #expect(updated[favoriteIndex].kind == .preset)

      await store.receive(.rowsUpdated(presets: updated, showActive: false)) {
        $0.presets = updated
        $0.sections = [
          .init(
            section: 0,
            sectionText: "Presets",
            sectionIndex: "0",
            presets: updated[...],
            presetSource: .active(1)
          )
        ]
      }
    }
  }

  @Test
  func editButtonTapped() async throws {
    try await initialized { store, presets in
      let sectionId = store.state.sections[0].id
      let preset = presets[0]

      await store.send(
        \.sections,
         .element(
          id: sectionId,
          action: .rows(.element(id: preset.id, action: .delegate(.editPreset(preset))))
         )
      )

      await store.receive(\.sections[id: sectionId].delegate.editPreset, preset)
      await store.receive(\.delegate, .edit(sectionId: store.state.sections[0].id, preset: presets[0]))
    }
  }

  @Test
  func hidePresetFirstTimeCancel() async throws {
    #expect(confirmPresetHiding == true)

    try await initialized { store, presets in
      let sectionId = store.state.sections[0].id
      let preset = presets[1]

      await store.send(
        \.sections,
         .element(
          id: sectionId,
          action: .rows(.element(id: preset.id, action: .delegate(.hidePreset(preset))))
         )
      )

      await store.receive(\.sections[id: sectionId].delegate.hidePreset, preset) {
        $0.destination = .alert(
          AlertState.confirmHidePreset(
            action: .hidePresetConfirmed(preset),
            displayName: preset.displayName
          )
        )
      }

      await store.send(.destination(.dismiss)) { $0.destination = nil }

      let updated = Preset.visible(for: 1)
      #expect(updated[1] == presets[1])
      #expect(confirmPresetHiding == true)
    }
  }

  @Test
  func hidePresetFirstTimeConfirm() async throws {
    #expect(confirmPresetHiding == true)

    try await initialized { store, presets in
      let sectionId = store.state.sections[0].id
      let preset = presets[1]

      await store.send(
        \.sections,
         .element(
          id: sectionId,
          action: .rows(.element(id: preset.id, action: .delegate(.hidePreset(preset))))
         )
      )

      await store.receive(\.sections[id: sectionId].delegate.hidePreset, preset) {
        $0.destination = .alert(
          AlertState.confirmHidePreset(
            action: .hidePresetConfirmed(preset),
            displayName: preset.displayName
          )
        )
      }

      var updated: [Preset] = presets // .init(presets.dropLast())

      await store.send(.destination(.presented(.alert(.hidePresetConfirmed(presets[1]))))) {
        $0.destination = nil
        $0.sections = [
          .init(
            section: 0,
            sectionText: "Presets",
            sectionIndex: "0",
            presets: updated[...],
            presetSource: .active(1)
          )
        ]
      }

      updated.remove(atOffsets: [1])
      await store.receive(.rowsUpdated(presets: updated, showActive: false)) {
        $0.presets = updated
        $0.sections = [
          .init(
            section: 0,
            sectionText: "Presets",
            sectionIndex: "0",
            presets: updated[...],
            presetSource: .active(1)
          )
        ]
      }

      updated = Preset.visible(for: 1)
      #expect(updated.count == 1)
      #expect(confirmPresetHiding == false)
    }
  }

  @Test
  func editVisbility() async throws {
    let store = try setup()

    await store.send(.editingVisibilityChanged(true)) {
      $0.scrollToTarget = nil
      $0.editingVisibility = true
    }

    let all = Preset.all(for: 1)

    await store.receive(\.rowsUpdated) {
      $0.presets = all
      $0.sections = [
        .init(
          section: 0,
          sectionText: "Presets",
          sectionIndex: "0",
          presets: all[...],
          presetSource: .active(1)
        )
      ]
    }

    let visible = Preset.visible(for: 1)
    await store.send(.editingVisibilityChanged(false)) {
      $0.scrollToTarget = nil
      $0.editingVisibility = false
    }

    await store.receive(\.rowsUpdated) {
      $0.presets = visible
      $0.sections = [
        .init(
          section: 0,
          sectionText: "Presets",
          sectionIndex: "0",
          presets: visible[...],
          presetSource: .active(1)
        )
      ]
    }

    await store.send(.deinitialize)
    await store.finish()
  }

#if SNAPSHOTS
  @Test
  func presetsListViewSearchingPreview() async throws {
    withDependencies {
      $0.defaultDatabase = previewDatabase()
    } operation: {
      let store = StoreOf<PresetsList>(initialState: .init(searchText: "ian")) { PresetsList() }
      let view = PresetsListView(store: store)
      withSnapshotTesting(record: .failed) {
        TestSupport.assertSnapshot(matching: view)
      }
    }
  }

  @Test
  func presetsListViewVisibilityEditing() async throws {
    withDependencies {
      $0.defaultDatabase = previewDatabase()
    } operation: {
      withSnapshotTesting(record: .failed) {
        TestSupport.assertSnapshot(matching: PresetsListView.previewEditing)
      }
    }
  }

  @Test
  func presetsListViewPreview() async throws {
    withDependencies {
      $0.defaultDatabase = previewDatabase()
    } operation: {
      withSnapshotTesting(record: .failed) {
        TestSupport.assertSnapshot(matching: PresetsListView.preview)
      }
    }
  }
#endif
}
