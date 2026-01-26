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
  },
  //  .snapshots(record: .failed)
)
@MainActor
struct PresetsListTests {

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

  var presets: [Preset] { Operations.presets(for: 1) }

  func setup(
    activeSoundFontId: SoundFont.ID? = 1,
    selectedSoundFontId: SoundFont.ID? = 1,
    searchText: String? = nil,
    editingVisibility: Bool = false
  ) throws -> TestStoreOf<PresetsList> {
    @Shared(.activeState) var activeState
    $activeState.withLock {
      $0.activeSoundFontId = activeSoundFontId
      $0.activePresetId = 1
    }

    @Shared(.selectedSoundFontId) var selectedSoundFontId
    $selectedSoundFontId.withLock { $0 = selectedSoundFontId }

    let store = TestStore(
      initialState: PresetsList.State(
        searchText: searchText,
        editingVisibility: editingVisibility
      )
    ) {
      PresetsList()
    }

    return store
  }

  func initialized(_ closure: (TestStoreOf<PresetsList>) async throws -> Void) async throws {
    let store = try setup()

    await store.send(.fetchPresets) {
      $0.sections = [.init(section: 0, presets: presets[...])]
      $0.scrollToPresetId = .init(presetId: Preset.ID(rawValue: 1), anchor: .center)
    }

    try await closure(store)

    await store.send(.deinitialize)
    await store.finish()
  }

  @Test
  func initializeWithNoSoundFontId() async throws {
    let store = try setup(activeSoundFontId: nil, selectedSoundFontId: nil)

    await store.send(.initialize)
    await store.receive(\.selectedSoundFontIdChanged) {
      $0.scrollToPresetId = .init(presetId: Preset.ID(rawValue: 1), anchor: .center)
      $0.sections = [.init(section: 0, presets: [])]
    }
    #expect(store.state.sections.count == 1)

    await store.send(.deinitialize)
    await store.finish()
  }

  @Test
  func initializeWithSoundFontId() async throws {
    let store = try setup()

    await store.send(.initialize)
    await store.receive(\.selectedSoundFontIdChanged)

    await store.send(.deinitialize)
    await store.finish()
  }

  @Test
  func fetchPresets() async throws {
    try await initialized { store in
      #expect(store.state.sections.count == 1)
    }
  }

  @Test
  func clearScrollTo() async throws {
    try await initialized { store in
      await store.send(\.clearScrollToPresetId) {
        $0.scrollToPresetId = nil
      }
    }
  }

  @Test(
    .dependencies {
      $0.continuousClock = TestClock()
    }
  )
  func searchPresets() async throws {
    @Dependency(\.continuousClock) var clock
    let testClock = clock as! TestClock<Duration>
    try await initialized { store in
      await store.send(\.sections, .element(id: 10_000, action: .delegate(.searchButtonTapped))) {
        $0.scrollToPresetId = nil
        $0.sections = [.init(section: 0, presets: [])]
        $0.isSearchFieldPresented = true
        $0.focusedField = .searchText
      }

      await store.send(.searchTextChanged("arp")) {
        $0.searchText = "arp"
        $0.sections = [.init(section: 0, presets: presets.filter({$0.displayName.contains("arp")})[...])]
      }

      await store.send(.clearSearchTextField) {
        $0.searchText = ""
        $0.sections = [.init(section: 0, presets: [])]
      }

      await store.send(.cancelSearchButtonTapped) {
        $0.isSearchFieldPresented = false
        $0.focusedField = nil
        $0.sections = [.init(section: 0, presets: presets[...])]
      }

      await store.receive(\.showActivePreset)

      await testClock.advance(by: PresetsList.delayBeforeShowingActivePreset)

      await store.receive(\.showActivePresetNow) {
        $0.scrollToPresetId = .init(presetId: Preset.ID(rawValue: 1), anchor: .center)
      }
    }
  }

  @Test(
    .dependencies {
      $0.continuousClock = TestClock()
      $0.fileManager = .liveValue
    }
  )
  func selectFromSearch() async throws {
    @Dependency(\.continuousClock) var clock
    try await initialized { store in

      await store.send(\.sections, .element(id: PresetsList.noGroupingSize, action: .delegate(.searchButtonTapped))) {
        $0.sections = [.init(section: 0, presets: [])]
        $0.isSearchFieldPresented = true
        $0.focusedField = .searchText
        $0.scrollToPresetId = nil
      }

      await store.send(.searchTextChanged("reset")) {
        $0.searchText = "reset"
        $0.sections = [
          .init(
            section: 0,
            presets: presets.filter({$0.displayName.contains("reset")})[...]
          )
        ]
      }

      await store.send(
        \.sections,
         .element(
          id: PresetsList.noGroupingSize,
          action: .rows(.element(id: 1, action: .delegate(.selectPreset(presets[0]))))
         )
      )

      await store.receive(\.sections[id: PresetsList.noGroupingSize].delegate.selectPreset)
    }
  }

  @Test
  func detectSoundFontIdChange() async throws {
    let store = try setup()
    await store.send(.initialize)

    await store.receive(\.selectedSoundFontIdChanged)

    @Shared(.selectedSoundFontId) var selectedSoundFontId
    $selectedSoundFontId.withLock { $0 = 2 }
    try await $selectedSoundFontId.load()

    await store.receive(\.selectedSoundFontIdChanged, 2) {
      $0.scrollToPresetId = nil
      $0.sections = [.init(
        section: 0,
        presets: Operations.presets(for: 2)[...]
      )]
    }

    await store.send(.deinitialize)
    await store.finish()
  }

  @Test(
    .dependencies {
      $0.fileManager.fileExists = { _ in true }
    }
  )
  func buttonTapped() async throws {
    @Shared(.activeState) var activeState
    try await initialized { store in
      await store.send(
        \.sections,
         .element(
          id: store.state.sections[0].id,
          action: .rows(.element(id: presets[1].id, action: .delegate(.selectPreset(presets[1]))))
         )
      )
      await store.receive(\.sections[id: store.state.sections[0].id].delegate.selectPreset, presets[1])
      #expect(activeState.activePresetId == presets[1].id)
    }
  }

  @Test(
    .dependencies {
      $0.fileManager.fileExists = { _ in false }
    }
  )
  func buttonTappedMissingFile() async throws {
    @Shared(.activeState) var activeState
    try await initialized { store in
      await store.send(
        \.sections,
         .element(
          id: store.state.sections[0].id,
          action: .rows(.element(id: presets[1].id, action: .delegate(.selectPreset(presets[1]))))
         )
      )
      await store.receive(\.sections[id: store.state.sections[0].id].delegate.selectPreset, presets[1]) {
        $0.destination = .alert(.missingFileForSelectedPreset(action: .missingFileForSelectedPreset(1), displayName: "Font 1"))
      }
    }
  }

  @Test
  func deleteFavoriteCancel() async throws {
    try await initialized { store in
      await store.send(
        \.sections,
         .element(
          id: store.state.sections[0].id,
          action: .rows(.element(id: presets[0].id, action: .delegate(.createFavorite(presets[0]))))
         )
      )

      await store.receive(\.sections[id: store.state.sections[0].id].delegate.createFavorite, presets[0]) {
        $0.sections[0] = .init(section: 0, presets: presets[...])
      }

      var updated = Operations.presets(for: nil)
      #expect(updated[1].kind == .favorite)

      await store.send(
        \.sections,
         .element(
          id: store.state.sections[0].id,
          action: .rows(.element(id: updated[1].id, action: .delegate(.deleteFavorite(updated[1]))))
         )
      )

      await store.receive(\.sections[id: store.state.sections[0].id].delegate.deleteFavorite, updated[1]) {
        $0.destination = .alert(
          AlertState.confirmDeleteFavorite(
            action: .deleteFavoriteConfirmed(updated[1]),
            displayName: updated[1].displayName
          )
        )
      }

      await store.send(.destination(.dismiss)) {
        $0.destination = nil
      }

      updated = Operations.presets(for: nil)
      #expect(updated[1].kind == .favorite)
    }
  }

  @Test
  func deleteFavoriteConfirm() async throws {
    try await initialized { store in
      await store.send(
        \.sections,
         .element(
          id: store.state.sections[0].id,
          action: .rows(.element(id: presets[0].id, action: .delegate(.createFavorite(presets[0]))))
         )
      )

      await store.receive(\.sections[id: store.state.sections[0].id].delegate.createFavorite, presets[0]) {
        $0.sections[0] = .init(section: 0, presets: presets[...])
      }

      var updated = Operations.presets(for: nil)
      #expect(updated[1].kind == .favorite)

      await store.send(
        \.sections,
         .element(
          id: store.state.sections[0].id,
          action: .rows(.element(id: updated[1].id, action: .delegate(.deleteFavorite(updated[1]))))
         )
      )

      await store.receive(\.sections[id: store.state.sections[0].id].delegate.deleteFavorite, updated[1]) {
        $0.destination = .alert(
          AlertState.confirmDeleteFavorite(
            action: .deleteFavoriteConfirmed(updated[1]),
            displayName: updated[1].displayName
          )
        )
      }

      await store.send(.destination(.presented(.alert(.deleteFavoriteConfirmed(updated[1]))))) {
        $0.destination = nil
        $0.sections = [.init(section: 0, presets: presets[...])]
      }

      updated = Operations.presets(for: nil)
      #expect(updated[1].kind == .preset)
    }
  }

  @Test
  func editButtonTapped() async throws {
    try await initialized { store in
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
    @Shared(.confirmPresetHiding) var confirmPresetHiding
    #expect(confirmPresetHiding == true)

    try await initialized { store in
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

      await store.send(.destination(.dismiss)) {
        $0.destination = nil
      }

      let updated = Operations.presets(for: nil)
      #expect(updated[1] == presets[1])
      #expect(confirmPresetHiding == true)
    }
  }

  @Test
  func hidePresetFirstTimeConfirm() async throws {
    @Shared(.confirmPresetHiding) var confirmPresetHiding
    #expect(confirmPresetHiding == true)

    try await initialized { store in
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

      var updated: [Preset] = .init(presets.dropLast())
      updated.remove(atOffsets: [1])

      await store.send(.destination(.presented(.alert(.hidePresetConfirmed(presets[1]))))) {
        $0.destination = nil
        $0.sections = [.init(section: 0, presets: updated[...])]
      }

      updated = Operations.presets(for: nil)
      #expect(updated.count == 1)
      #expect(confirmPresetHiding == false)
    }
  }

  @Test
  func editVisbility() async throws {
    let store = try setup()

    await store.send(.editingVisibilityChanged(true)) {
      $0.sections = [.init(section: 0, presets: Operations.allPresets(for: 1)[...])]
      $0.scrollToPresetId = nil
      $0.editingVisibility = true
    }

    await store.send(.editingVisibilityChanged(false)) {
      $0.sections = [.init(section: 0, presets: Operations.presets(for: 1)[...])]
      $0.scrollToPresetId = nil
      $0.editingVisibility = false
    }

    await store.send(.deinitialize)
    await store.finish()
  }

  @Test
  func presetsListViewSearchingPreview() async throws {
    let store = StoreOf<PresetsList>(initialState: .init(searchText: "ian")) {
      PresetsList()
    }
    let view = PresetsListView(store: store)

    try withSnapshotTesting(record: .failed) {
      try TestSupport.assertSnapshot(matching: view)
    }
  }

  @Test
  func presetsListViewVisibilityEditing() async throws {
    try withSnapshotTesting(record: .failed) {
      try TestSupport.assertSnapshot(matching: PresetsListView.previewEditing)
    }
  }

  @Test
  func presetsListViewPreview() async throws {
    try withSnapshotTesting(record: .failed) {
      try TestSupport.assertSnapshot(matching: PresetsListView.preview)
    }
  }
}

extension PresetsList.Action.Delegate: Equatable {
  public static func == (lhs: PresetsList.Action.Delegate, rhs: PresetsList.Action.Delegate) -> Bool {
    switch (lhs, rhs) {
    case let (.edit(a, b), .edit(c, d)):
      return (a, b) == (c, d)
    }
  }
}
