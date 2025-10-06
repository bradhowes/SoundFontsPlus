import Testing

import ComposableArchitecture
import Dependencies
import DependenciesTestSupport
import Models
import SnapshotTesting
import Tagged

@testable import Presets

@Suite(
  .dependencies {
    $0.defaultDatabase = try appDatabase()
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
        originalName: name,
        soundFontId: 1,
        displayName: name,
        notes: "",
        kind: .preset
      )
    }
  }

  let presets: [Preset] = makePresets(
    [
      (0, "Yamaha Grand Piano"),
      (1, "Bright Yamaha Grand"),
      (2, "Electric Piano"),
      (3, "Honky Tonk"),
      (4, "Rhodes EP"),
      (5, "Legend EP 2"),
      (6, "Harpsichord"),
      (7, "Clavinet"),
      (8, "Celesta"),
      (9, "Glockenspiel")
    ]
  )

  func setup(
    activeSoundFontId: SoundFont.ID? = .init(rawValue: 1),
    selectedSoundFontId: SoundFont.ID? = .init(rawValue: 1),
    searchText: String? = nil,
    visibilityEditMode: Bool = false
  ) throws -> TestStoreOf<PresetsList> {
    @Shared(.activeState) var activeState
    $activeState.withLock {
      $0.activeSoundFontId = activeSoundFontId
      $0.activePresetId = .init(rawValue: 1)
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

  @Test func initializeWithNoSoundFontId() async throws {
    let store = try setup(activeSoundFontId: nil, selectedSoundFontId: nil)
    #expect(store.state.sections.count == 0)

    await store.send(.initialize)
    await store.receive(\.selectedSoundFontIdChanged) {
      $0.scrollToPresetId = .init(presetId: Preset.ID(rawValue: 1), anchor: .center)
      $0.sections = [.init(section: 0, presets: [])]
    }
    #expect(store.state.sections.count == 1)

    await store.send(.stop)
    await store.finish()
  }

  @Test func initializeWithSoundFontId() async throws {
    let store = try setup()
    #expect(store.state.sections.count == 0)

    await store.send(.initialize)
    await store.receive(\.selectedSoundFontIdChanged) {
      $0.sections = [.init(section: 0, presets: presets[...])]
    }
    #expect(store.state.sections.count == 1)

    await store.send(.stop)
    await store.finish()
  }

  @Test func fetchPresets() async throws {
    let store = try setup()

    await store.send(.fetchPresets) {
      $0.sections = [.init(section: 0, presets: presets[...])]
      $0.scrollToPresetId = .init(presetId: Preset.ID(rawValue: 1), anchor: .center)
    }
    #expect(store.state.sections.count == 1)

    await store.send(.stop)
    await store.finish()
  }

  @Test func clearScrollTo() async throws {
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

    await store.send(.searchTextChanged("arp")) {
      $0.searchText = "arp"
      $0.sections = [.init(section: 0, presets: presets.filter({$0.displayName.contains("arp")})[...])]
    }

    await store.send(\.sections, .element(id: PresetsList.noGroupingSize, action: .rows(.element(id: 7, action: .delegate(.selectPreset(presets[6])))))) {
      $0.isSearchFieldPresented = false
      $0.focusedField = nil
      $0.sections = [.init(section: 0, presets: presets[...])]
    }

    await testClock.advance(by: PresetsList.delayBeforeShowingActivePreset)

    await store.receive(\.showActivePreset)

    await store.receive(\.showActivePresetNow) {
      $0.scrollToPresetId = .init(presetId: 7, anchor: .center)
    }

    await store.send(.stop)
    await store.finish()
  }

  @Test func detectSoundFontIdChange() async throws {
    let store = try setup()
    await store.send(.initialize)

    await store.receive(\.selectedSoundFontIdChanged, nil) {
      $0.sections = [.init(section: 0, presets: presets[...])]
    }

    @Shared(.selectedSoundFontId) var selectedSoundFontId
    $selectedSoundFontId.withLock { $0 = .init(rawValue: 4) }
    try await $selectedSoundFontId.load()

    await store.receive(\.selectedSoundFontIdChanged, .init(rawValue: 4)) {
      $0.scrollToPresetId = nil
      $0.sections = [.init(
        section: 0,
        presets: [
          .init(
            id: 31,
            index: 0,
            bank: 0,
            program: 1,
            originalName: "Nice Piano",
            soundFontId: 4,
            displayName: "Nice Piano"
          )]
      )]
    }

    await store.send(.stop)
    await store.finish()
  }

  @Test func buttonTapped() async throws {
    @Shared(.activeState) var activeState
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
        action: .rows(.element(id: presets[7].id, action: .buttonTapped))
       )
    )

    await store.receive(
      \.sections,
       .element(
        id: store.state.sections[0].id,
        action: .rows(.element(id: presets[7].id, action: .delegate(.selectPreset(presets[7]))))
       )
    )

    #expect(activeState.activePresetId == presets[7].id)

    await store.send(.stop)
    await store.finish()
  }

  @Test func deleteFavoriteCancel() async throws {
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
    presetsWithFavorite.insert(.init(id: 32, index: 0, bank: 0, program: 0, originalName: "Yamaha Grand Piano", soundFontId: 1, displayName: "Yamaha Grand Piano copy"), at: 1)
    presetsWithFavorite[1].kind = .favorite

    await store.receive(
      \.sections,
       .element(
        id: store.state.sections[0].id,
        action: .rows(.element(id: presets[0].id, action: .delegate(.createFavorite(presets[0]))))
       )
    ) {
      $0.sections[0] = .init(section: 0, presets: presetsWithFavorite[...])
      // $0.sections[0].rows = .init(uniqueElements: presetsWithFavorite.map { .init(preset: $0) })
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

  @Test func deleteFavoriteConfirm() async throws {
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
    presetsWithFavorite.insert(.init(id: 32, index: 0, bank: 0, program: 0, originalName: "Yamaha Grand Piano", soundFontId: 1, displayName: "Yamaha Grand Piano copy"), at: 1)
    presetsWithFavorite[1].kind = .favorite

    await store.receive(
      \.sections,
       .element(
        id: store.state.sections[0].id,
        action: .rows(.element(id: presets[0].id, action: .delegate(.createFavorite(presets[0]))))
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

  @Test func editButtonTapped() async throws {
    let store = try setup()

    await store.send(.fetchPresets) {
      $0.sections = [.init(section: 0, presets: presets[...])]
      $0.scrollToPresetId = .init(presetId: Preset.ID(rawValue: 1), anchor: .center)
    }

    await store.send(
      \.sections,
       .element(
        id: store.state.sections[0].id,
        action: .rows(.element(id: presets[0].id, action: .editButtonTapped))
       )
    )

    await store.receive(
      \.sections,
       .element(
        id: store.state.sections[0].id,
        action: .rows(.element(id: presets[0].id, action: .delegate(.editPreset(presets[0]))))
       )
    )

    await store.receive(\.delegate, .edit(sectionId: store.state.sections[0].id, preset: presets[0]))

    await store.send(.stop)
    await store.finish()
  }

  @Test func hidePresetFirstTimeCancel() async throws {
    let store = try setup()
    @Shared(.confirmPresetHiding) var confirmPresetHiding
    #expect(confirmPresetHiding == true)

    await store.send(.fetchPresets) {
      $0.sections = [.init(section: 0, presets: presets[...])]
      $0.scrollToPresetId = .init(presetId: Preset.ID(rawValue: 1), anchor: .center)
    }

    await store.send(
      \.sections,
       .element(
        id: store.state.sections[0].id,
        action: .rows(.element(id: presets[1].id, action: .hidePresetButtonTapped))
       )
    )

    await store.receive(
      \.sections,
       .element(
        id: store.state.sections[0].id,
        action: .rows(.element(id: presets[1].id, action: .delegate(.hidePreset(presets[1]))))
       )
    ) {
      $0.destination = .alert(
        AlertState.confirmHidePreset(
          action: .hidePresetConfirmed(presets[1]),
          displayName: presets[1].displayName
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

  @Test func hidePresetFirstTimeConfirm() async throws {
    let store = try setup()
    @Shared(.confirmPresetHiding) var confirmPresetHiding
    #expect(confirmPresetHiding == true)

    await store.send(.fetchPresets) {
      $0.sections = [.init(section: 0, presets: presets[...])]
      $0.scrollToPresetId = .init(presetId: Preset.ID(rawValue: 1), anchor: .center)
    }

    await store.send(
      \.sections,
       .element(
        id: store.state.sections[0].id,
        action: .rows(.element(id: presets[1].id, action: .hidePresetButtonTapped))
       )
    )

    await store.receive(
      \.sections,
       .element(
        id: store.state.sections[0].id,
        action: .rows(.element(id: presets[1].id, action: .delegate(.hidePreset(presets[1]))))
       )
    ) {
      $0.destination = .alert(
        AlertState.confirmHidePreset(
          action: .hidePresetConfirmed(presets[1]),
          displayName: presets[1].displayName
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
    #expect(updated[1] != presets[1])
    #expect(confirmPresetHiding == false)

    await store.send(.stop)
    await store.finish()
  }

  @Test func presetsListViewSearchingPreview() async throws {
    let store = StoreOf<PresetsList>(initialState: .init(searchText: "ian")) {
      PresetsList()
    }
    let view = PresetsListView(store: store)

    try withSnapshotTesting(record: .failed) {
      try assertSnapshot(
        of: view,
        as: .wait(for: 1, on: .image(
          drawHierarchyInKeyWindow: false,
          layout: .fixed(width: 400, height: 800)
        ))
      )
    }
  }

  @Test func presetsListViewVisibilityEditing() async throws {
    try withSnapshotTesting(record: .failed) {
      try assertSnapshot(
        of: PresetsListView.previewEditing,
        as: .wait(for: 1, on: .image(
          drawHierarchyInKeyWindow: false,
          layout: .fixed(width: 400, height: 800)
        ))
      )
    }
  }

  @Test func presetsListViewPreview() async throws {
    try withSnapshotTesting(record: .failed) {
      try assertSnapshot(
        of: PresetsListView.preview,
        as: .wait(for: 1, on: .image(
          drawHierarchyInKeyWindow: false,
          layout: .fixed(width: 400, height: 800)
        ))
      )
    }
  }
}
