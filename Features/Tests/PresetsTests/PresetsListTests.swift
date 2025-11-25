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
        kind: .preset
      )
    }
  }

  let presets: [Preset] = makePresets(
    [
      (0, "Font 1 Preset 1"),
      (1, "Font 1 Preset 2")
    ]
  )

  func setup(
    activeSoundFontId: SoundFont.ID? = 1,
    selectedSoundFontId: SoundFont.ID? = 1,
    searchText: String? = nil,
    visibilityEditMode: Bool = false
  ) throws -> TestStoreOf<PresetsList> {
    @Shared(.appActiveState) var activeState
    $activeState.withLock {
      $0.activeSoundFontId = activeSoundFontId
      $0.activePresetId = 1
    }

    @Shared(.selectedSoundFontId) var selectedSoundFontId
    $selectedSoundFontId.withLock { $0 = selectedSoundFontId }

    let store = TestStore(
      initialState: PresetsList.State(
        searchText: searchText,
        visibilityEditMode: visibilityEditMode
      )
    ) {
      PresetsList()
    }

    return store
  }

  @Test
  func initializeWithNoSoundFontId() async throws {
    let store = try setup(activeSoundFontId: nil, selectedSoundFontId: nil)
    #expect(store.state.sections.isEmpty)

    await store.send(.initialize)
    await store.receive(\.selectedSoundFontIdChanged) {
      $0.scrollToPresetId = .init(presetId: Preset.ID(rawValue: 1), anchor: .center)
      $0.sections = [.init(section: 0, presets: [])]
    }
    #expect(store.state.sections.count == 1)

    await store.send(.stop)
    await store.finish()
  }

  @Test
  func initializeWithSoundFontId() async throws {
    let store = try setup()
    #expect(store.state.sections.isEmpty)

    await store.send(.initialize)
    await store.receive(\.selectedSoundFontIdChanged) {
      $0.sections = [.init(section: 0, presets: presets[...])]
    }
    #expect(store.state.sections.count == 1)

    await store.send(.stop)
    await store.finish()
  }

  @Test
  func fetchPresets() async throws {
    let store = try setup()

    await store.send(.fetchPresets) {
      $0.sections = [.init(section: 0, presets: presets[...])]
      $0.scrollToPresetId = .init(presetId: Preset.ID(rawValue: 1), anchor: .center)
    }
    #expect(store.state.sections.count == 1)

    await store.send(.stop)
    await store.finish()
  }

  @Test
  func clearScrollTo() async throws {
    let store = try setup()

    await store.send(.fetchPresets) {
      $0.sections = [.init(section: 0, presets: presets[...])]
      $0.scrollToPresetId = .init(presetId: Preset.ID(rawValue: 1), anchor: .center)
    }
    #expect(store.state.sections.count == 1)

    await store.send(\.clearScrollToPresetId) {
      $0.scrollToPresetId = nil
    }

    await store.send(.stop)
    await store.finish()
  }

  @Test(
    .dependencies {
      $0.continuousClock = TestClock()
    }
  )
  func searchPresets() async throws {
    @Dependency(\.continuousClock) var clock
    let testClock = clock as! TestClock<Duration>
    let store = try setup()

    await store.send(.fetchPresets) {
      $0.sections = [.init(section: 0, presets: presets[...])]
      $0.scrollToPresetId = .init(presetId: Preset.ID(rawValue: 1), anchor: .center)
    }
    #expect(store.state.sections.count == 1)

    await store.send(\.sections, .element(id: 10_000, action: .searchButtonTapped))
    await store.receive(\.sections, .element(id: 10_000, action: .delegate(.searchButtonTapped))) {
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

    await store.send(.stop)
    await store.finish()
  }

  @Test(
    .dependencies {
      $0.continuousClock = TestClock()
    }
  )
  func selectFromSearch() async throws {
    @Dependency(\.continuousClock) var clock
    let testClock = clock as! TestClock<Duration>
    let store = try setup()

    await store.send(.fetchPresets) {
      $0.sections = [.init(section: 0, presets: presets[...])]
      $0.scrollToPresetId = .init(presetId: Preset.ID(rawValue: 1), anchor: .center)
    }
    #expect(store.state.sections.count == 1)

    await store.send(\.sections, .element(id: PresetsList.noGroupingSize, action: .searchButtonTapped))
    await store.receive(\.sections, .element(id: PresetsList.noGroupingSize, action: .delegate(.searchButtonTapped))) {
      $0.sections = [.init(section: 0, presets: [])]
      $0.isSearchFieldPresented = true
      $0.focusedField = .searchText
      $0.scrollToPresetId = nil
    }

    await store.send(.searchTextChanged("reset")) {
      $0.searchText = "reset"
      $0.sections = [.init(section: 0, presets: presets.filter({$0.displayName.contains("reset")})[...])]
    }

    await store.send(
      \.sections,
       .element(
        id: PresetsList.noGroupingSize,
        action: .rows(.element(id: 1, action: .delegate(.selectPreset(presets[0]))))
       )
    )

    await store.receive(
      \.sections,
       .element(
        id: PresetsList.noGroupingSize,
        action: .delegate(.selectPreset(presets[0]))
       )
    ) {
      $0.isSearchFieldPresented = false
      $0.focusedField = nil
      $0.sections = [.init(section: 0, presets: presets[...])]
    }

    await testClock.advance(by: PresetsList.delayBeforeShowingActivePreset)

    await store.receive(\.showActivePreset)

    await store.receive(\.showActivePresetNow) {
      $0.scrollToPresetId = .init(presetId: 1, anchor: .center)
    }

    await store.send(.stop)
    await store.finish()
  }

  @Test
  func detectSoundFontIdChange() async throws {
    let store = try setup()
    await store.send(.initialize)

    await store.receive(\.selectedSoundFontIdChanged, nil) {
      $0.sections = [.init(section: 0, presets: presets[...])]
    }

    @Shared(.selectedSoundFontId) var selectedSoundFontId
    $selectedSoundFontId.withLock { $0 = 2 }
    try await $selectedSoundFontId.load()

    await store.receive(\.selectedSoundFontIdChanged, 2) {
      $0.scrollToPresetId = nil
      $0.sections = [.init(
        section: 0,
        presets: [
          .init(
            id: 3,
            index: 0,
            bank: 0,
            program: 0,
            originalName: "Original Preset 1",
            soundFontId: 2,
            displayName: "Font 2 Preset 1"
          ),
          .init(
            id: 4,
            index: 1,
            bank: 0,
            program: 1,
            originalName: "Original Preset 2",
            soundFontId: 2,
            displayName: "Font 2 Preset 2"
          )
        ]
      )]
    }

    await store.send(.stop)
    await store.finish()
  }

  @Test
  func buttonTapped() async throws {
    @Shared(.appActiveState) var activeState
    let store = try setup()

    await store.send(.fetchPresets) {
      $0.sections = [.init(section: 0, presets: presets[...])]
      $0.scrollToPresetId = .init(presetId: Preset.ID(rawValue: 1), anchor: .center)
    }
    #expect(activeState.activePresetId == 1)

    await store.send(
      \.sections,
       .element(
        id: store.state.sections[0].id,
        action: .rows(.element(id: presets[1].id, action: .buttonTapped))
       )
    )

    await store.receive(
      \.sections,
       .element(
        id: store.state.sections[0].id,
        action: .rows(.element(id: presets[1].id, action: .delegate(.selectPreset(presets[1]))))
       )
    )

    await store.receive(
      \.sections,
       .element(
        id: store.state.sections[0].id,
        action: .delegate(.selectPreset(presets[1]))
       )
    )

    #expect(activeState.activePresetId == presets[1].id)

    await store.send(.stop)
    await store.finish()
  }

  @Test
  func deleteFavoriteCancel() async throws {
    let store = try setup()

    await store.send(.fetchPresets) {
      $0.sections = [.init(section: 0, presets: presets[...])]
      $0.scrollToPresetId = .init(presetId: Preset.ID(rawValue: 1), anchor: .center)
    }

    await store.send(
      \.sections,
       .element(
        id: store.state.sections[0].id,
        action: .rows(.element(id: presets[0].id, action: .favoriteButtonTapped))
       )
    )

    var presetsWithFavorite = presets
    presetsWithFavorite.insert(
      .init(
        id: 5,
        index: 0,
        bank: 0,
        program: 0,
        originalName: "Original Preset 1",
        soundFontId: 1,
        displayName: "Font 1 Preset 1 copy"
      ),
      at: 1
    )
    presetsWithFavorite[1].kind = .favorite

    await store.receive(
      \.sections,
       .element(
        id: store.state.sections[0].id,
        action: .rows(.element(id: presets[0].id, action: .delegate(.createFavorite(presets[0]))))
       )
    )

    await store.receive(
      \.sections,
       .element(
        id: store.state.sections[0].id,
        action: .delegate(.createFavorite(presets[0]))
       )
    ) {
      $0.sections[0] = .init(section: 0, presets: presetsWithFavorite[...])
    }

    var updated = Operations.presets(for: nil)
    #expect(updated[1].kind == .favorite)

    await store.send(
      \.sections,
       .element(
        id: store.state.sections[0].id,
        action: .rows(.element(id: updated[1].id, action: .deleteFavoriteButtonTapped))
       )
    )

    await store.receive(
      \.sections,
       .element(
        id: store.state.sections[0].id,
        action: .rows(.element(id: updated[1].id, action: .delegate(.deleteFavorite(updated[1]))))
       )
    )

    await store.receive(
      \.sections,
       .element(
        id: store.state.sections[0].id,
        action: .delegate(.deleteFavorite(updated[1]))
       )
    ) {
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

    await store.send(.stop)
    await store.finish()
  }

  @Test
  func deleteFavoriteConfirm() async throws {
    let store = try setup()

    await store.send(.fetchPresets) {
      $0.sections = [.init(section: 0, presets: presets[...])]
      $0.scrollToPresetId = .init(presetId: Preset.ID(rawValue: 1), anchor: .center)
    }

    await store.send(
      \.sections,
       .element(
        id: store.state.sections[0].id,
        action: .rows(.element(id: presets[0].id, action: .favoriteButtonTapped))
       )
    )

    var presetsWithFavorite = presets
    presetsWithFavorite.insert(
      .init(
        id: 5,
        index: 0,
        bank: 0,
        program: 0,
        originalName: "Original Preset 1",
        soundFontId: 1,
        displayName: "Font 1 Preset 1 copy"
      ),
      at: 1
    )
    presetsWithFavorite[1].kind = .favorite

    await store.receive(
      \.sections,
       .element(
        id: store.state.sections[0].id,
        action: .rows(.element(id: presets[0].id, action: .delegate(.createFavorite(presets[0]))))
       )
    )

    await store.receive(
      \.sections,
       .element(
        id: store.state.sections[0].id,
        action: .delegate(.createFavorite(presets[0]))
       )
    ) {
      $0.sections[0] = .init(section: 0, presets: presetsWithFavorite[...])
    }

    var updated = Operations.presets(for: nil)
    #expect(updated[1].kind == .favorite)

    await store.send(
      \.sections,
       .element(
        id: store.state.sections[0].id,
        action: .rows(.element(id: updated[1].id, action: .deleteFavoriteButtonTapped))
       )
    )

    await store.receive(
      \.sections,
       .element(
        id: store.state.sections[0].id,
        action: .rows(.element(id: updated[1].id, action: .delegate(.deleteFavorite(updated[1]))))
       )
    )

    await store.receive(
      \.sections,
       .element(
        id: store.state.sections[0].id,
        action: .delegate(.deleteFavorite(updated[1]))
       )
    ) {
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

    await store.send(.stop)
    await store.finish()
  }

  @Test
  func editButtonTapped() async throws {
    let store = try setup()

    await store.send(.fetchPresets) {
      $0.sections = [.init(section: 0, presets: presets[...])]
      $0.scrollToPresetId = .init(presetId: Preset.ID(rawValue: 1), anchor: .center)
    }

    let sectionId = store.state.sections[0].id
    let preset = presets[0]

    await store.send(
      \.sections,
       .element(
        id: sectionId,
        action: .rows(.element(id: preset.id, action: .editButtonTapped))
       )
    )

    await store.receive(
      \.sections,
       .element(
        id: sectionId,
        action: .rows(.element(id: preset.id, action: .delegate(.editPreset(preset))))
       )
    )

    await store.receive(
      \.sections,
       .element(
        id: sectionId,
        action: .delegate(.editPreset(preset))
       )
    )

    await store.receive(\.delegate, .edit(sectionId: store.state.sections[0].id, preset: presets[0]))

    await store.send(.stop)
    await store.finish()
  }

  @Test
  func hidePresetFirstTimeCancel() async throws {
    let store = try setup()
    @Shared(.confirmPresetHiding) var confirmPresetHiding
    #expect(confirmPresetHiding == true)

    await store.send(.fetchPresets) {
      $0.sections = [.init(section: 0, presets: presets[...])]
      $0.scrollToPresetId = .init(presetId: Preset.ID(rawValue: 1), anchor: .center)
    }

    let sectionId = store.state.sections[0].id
    let preset = presets[1]

    await store.send(
      \.sections,
       .element(
        id: sectionId,
        action: .rows(.element(id: preset.id, action: .hidePresetButtonTapped))
       )
    )

    await store.receive(
      \.sections,
       .element(
        id: sectionId,
        action: .rows(.element(id: preset.id, action: .delegate(.hidePreset(preset))))
       )
    )

    await store.receive(
      \.sections,
       .element(
        id: sectionId,
        action: .delegate(.hidePreset(preset))
       )
    ) {
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

    await store.send(.stop)
    await store.finish()
  }

  @Test
  func hidePresetFirstTimeConfirm() async throws {
    let store = try setup()
    @Shared(.confirmPresetHiding) var confirmPresetHiding
    #expect(confirmPresetHiding == true)

    await store.send(.fetchPresets) {
      $0.sections = [.init(section: 0, presets: presets[...])]
      $0.scrollToPresetId = .init(presetId: Preset.ID(rawValue: 1), anchor: .center)
    }

    let sectionId = store.state.sections[0].id
    let preset = presets[1]

    await store.send(
      \.sections,
       .element(
        id: sectionId,
        action: .rows(.element(id: preset.id, action: .hidePresetButtonTapped))
       )
    )

    await store.receive(
      \.sections,
       .element(
        id: sectionId,
        action: .rows(.element(id: preset.id, action: .delegate(.hidePreset(preset))))
       )
    )

    await store.receive(
        \.sections,
         .element(
          id: sectionId,
          action: .delegate(.hidePreset(preset))
         )
      ) {
      $0.destination = .alert(
        AlertState.confirmHidePreset(
          action: .hidePresetConfirmed(preset),
          displayName: preset.displayName
        )
      )
    }

    var updated = presets
    updated.remove(atOffsets: [1])

    await store.send(.destination(.presented(.alert(.hidePresetConfirmed(presets[1]))))) {
      $0.destination = nil
      $0.sections = [.init(section: 0, presets: updated[...])]
    }

    updated = Operations.presets(for: nil)
    #expect(updated.count == 1)
    #expect(confirmPresetHiding == false)

    await store.send(.stop)
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

  func presetsListViewPreview() async throws {
    try withSnapshotTesting(record: .failed) {
      try TestSupport.assertSnapshot(matching: PresetsListView.preview)
    }
  }
}
