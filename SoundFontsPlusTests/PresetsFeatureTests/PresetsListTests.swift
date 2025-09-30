import Testing

import ComposableArchitecture
import Dependencies
import SnapshotTesting
import Tagged

@testable import SoundFontsPlus

extension BaseTestSuite {

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

  @MainActor
  struct PresetsListTests {
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
  }
}

extension BaseTestSuite.PresetsListTests {

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
      // $0.scrollToPresetId = .init(presetId: Preset.ID(rawValue: 1), anchor: .center)
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

  @Test func searchPresets() async throws {
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
    await store.receive(\.showActivePresetNow) {
      $0.scrollToPresetId = .init(presetId: Preset.ID(rawValue: 1), anchor: .center)
    }

    await store.send(.stop)
    await store.finish()
  }

  @Test func selectFromSearch() async throws {
    let store = try setup()

    await store.send(.fetchPresets) {
      $0.sections = [.init(section: 0, presets: presets[...])]
      $0.scrollToPresetId = .init(presetId: Preset.ID(rawValue: 1), anchor: .center)
    }
    #expect(store.state.sections.count == 1)

    await store.send(\.sections, .element(id: 10_000, action: .searchButtonTapped))
    await store.receive(\.sections, .element(id: 10_000, action: .delegate(.searchButtonTapped))) {
      $0.sections = [.init(section: 0, presets: [])]
      $0.isSearchFieldPresented = true
      $0.focusedField = .searchText
      $0.scrollToPresetId = nil
    }

    await store.send(.searchTextChanged("arp")) {
      $0.searchText = "arp"
      $0.sections = [.init(section: 0, presets: presets.filter({$0.displayName.contains("arp")})[...])]
    }

    await store.send(\.sections, .element(id: 10_000, action: .rows(.element(id: 7, action: .delegate(.selectPreset(presets[6])))))) {
      $0.isSearchFieldPresented = false
      $0.focusedField = nil
      $0.sections = [.init(section: 0, presets: presets[...])]
    }

    await store.receive(\.showActivePreset)
    await store.receive(\.showActivePresetNow, timeout: .seconds(2)) {
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

//
//  @Test func seesButtonTap() async throws {
//    try await initialize { soundFonts, store in
//      let preset = soundFonts[0].presets[3]
//      await store.send(.sections(.element(id: 0, action: .rows(.element(id: 4, action: .buttonTapped)))))
//      await store.receive(.sections(.element(id: 0, action: .rows(.element(id: 4, action: .delegate(.selectPreset(preset)))))))
//    }
//  }
//
//  @Test func editButtonTapped() async throws {
//    try await initialize { soundFonts, store in
//      let preset = soundFonts[0].presets[3]
//      await store.send(.sections(.element(id: 0, action: .rows(.element(id: 4, action: .editButtonTapped)))))
//      await store.receive(.sections(.element(id: 0, action: .rows(.element(id: 4, action: .delegate(.editPreset(preset))))))) {
//        $0.destination = .edit(PresetEditor.State(preset: preset))
//      }
//      await store.send(.destination(.presented(.edit(.acceptButtonTapped))))
//      await store.receive(.destination(.dismiss)) {
//        $0.destination = nil
//      }
//    }
//  }
//
//  @Test func fetchPresets() async throws {
//    try await initialize { soundFonts, store in
//      let sections = store.state.sections.count
//
//      @Dependency(\.defaultDatabase) var database
//      let presets = soundFonts[0].presets
//      for preset in presets[0..<15] {
//        try await database.write {
//          var preset = preset
//          preset.visible = false
//          try preset.save($0)
//        }
//      }
//
//      store.exhaustivity = .off
//      await store.send(.fetchPresets)
//      #expect(store.state.sections.count < sections)
//      await store.send(.visibilityEditMode(true)) {
//        $0.editingVisibility = true
//      }
//      #expect(store.state.sections.count == sections)
//      await store.send(.visibilityEditMode(false)) {
//        $0.editingVisibility = false
//      }
//      #expect(store.state.sections.count < sections)
//    }
//  }
//
//  @Test func hidePreset() async throws {
//    try await initialize { soundFonts, store in
//      var preset = soundFonts[0].presets[0]
//      #expect(preset.visible == true)
//
//      @Shared(.stopConfirmingPresetHiding) var stopConfirmingPresetHiding
//      $stopConfirmingPresetHiding.withLock { $0 = true }
//      #expect(store.state.sections[0].rows[0].preset.displayName == "Piano 1")
//
//      await store.send(.sections(.element(id: 0, action: .rows(.element(id: 1, action: .hideButtonTapped)))))
//      store.exhaustivity = .off
//      await store.receive(.sections(.element(id: 0, action: .rows(.element(id: 1, action: .delegate(.hidePreset(preset)))))))
//
//      preset = try await TestSupport.fetchPreset(presetId: preset.id)
//      #expect(preset.visible == false)
//
//      await store.receive(.fetchPresets)
//      #expect(store.state.sections[0].rows[0].preset.displayName == "Piano 2")
//    }
//  }
//
  @Test func presetsListViewSearchingPreview() async throws {
    let store = StoreOf<PresetsList>(initialState: .init(searchText: "ian")) {
      PresetsList()
    }
    let view = PresetsListView(store: store)

    try withSnapshotTesting(record: .failed) {
      try BaseTestSuite.assertSnap(
        matching: view,
        size: .init(width: 400, height: 800),
        colorScheme: .dark
      )
    }
  }

  @Test func presetsListViewVisibilityEditing() async throws {
    let store = StoreOf<PresetsList>(initialState: .init(visibilityEditMode: true)) {
      PresetsList()
    }
    let view = PresetsListView(store: store)

    try withSnapshotTesting(record: .failed) {
      try BaseTestSuite.assertSnap(
        matching: view,
        size: .init(width: 400, height: 800),
        colorScheme: .dark
      )
    }
  }

  @Test func presetsListViewPreview() async throws {
    try withSnapshotTesting(record: .failed) {
      try BaseTestSuite.assertSnap(
        matching: PresetsListView.preview,
        size: .init(width: 400, height: 800),
        colorScheme: .dark
      )
    }
  }
}
