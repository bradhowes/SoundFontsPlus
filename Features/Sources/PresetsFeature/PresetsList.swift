// Copyright © 2025 Brad Howes. All rights reserved.

import Algorithms
import ComposableArchitecture
import GRDB
import SF2ResourceFiles
import SwiftUI
import Models

@Reducer
public struct PresetsList {

  @Reducer(state: .equatable, .sendable, action: .equatable)
  public enum Destination: Equatable {
    case edit(PresetEditor)
  }

  @ObservableState
  public struct State: Equatable {
    @Presents var destination: Destination.State?
    var soundFont: SoundFont?
    var sections: IdentifiedArrayOf<PresetsListSection.State>
    var editingVisibility: Bool

    public init(soundFont: SoundFont?, editingVisibility: Bool = false) {
      self.soundFont = soundFont
      if let soundFont {
        self.sections = generatePresetSections(soundFont: soundFont, editing: false)
      } else {
        self.sections = []
      }
      self.editingVisibility = editingVisibility
    }

    /**
     Update any group that is showing the given preset

     - parameter preset: the preset to update with
     - returns: true if updated
     */
    mutating func update(preset: Preset) {
      for var section in sections where section.update(preset: preset) {
        sections[section.section] = section
        break
      }
    }
  }

  public enum Action: Equatable {
    case destination(PresentationAction<Destination.Action>)
    case fetchPresets
    case onAppear
    case sections(IdentifiedActionOf<PresetsListSection>)
    case selectedSoundFontIdChanged(SoundFont.ID?)
    case stop
    case toggleEditMode
  }

  public init() {}

  @Dependency(\.defaultDatabase) var database
  @Shared(.activeState) var activeState

  private let pubisherCancelId = "selectedSoundFontChangedPublisher"

  public var body: some ReducerOf<Self> {
    Reduce<State, Action> { state, action in
      switch action {

      case .destination(.presented(.edit(.acceptButtonTapped))): return updatePreset(&state)
      case .destination: return .none
      case .fetchPresets: return fetchPresets(&state)
      case .onAppear: return monitorSelectedSoundFont()
      case let .sections(.element(id: _, action: .rows(.element(id: _, action: .delegate(.editPreset(preset)))))):
        return editPreset(&state, preset: preset)
      case let .sections(.element(id: _, action: .rows(.element(id: _, action: .delegate(.hidePreset(preset)))))):
        return hidePreset(&state, preset: preset)
      case let .sections(.element(id: _, action: .rows(.element(id: _, action: .delegate(.selectPreset(preset)))))):
        return selectPreset(&state, preset: preset)
      case .sections: return .none
      case .selectedSoundFontIdChanged(let soundFontId): return setSoundFont(&state, soundFontId: soundFontId)
      case .stop: return .cancel(id: pubisherCancelId)
      case .toggleEditMode: return toggleEditMode(&state)
      }
    }
    .forEach(\.sections, action: \.sections) {
      PresetsListSection()
    }
    .ifLet(\.$destination, action: \.destination)
  }
}

// extension PresetsList.Destination.State: Equatable {}

func generatePresetSections(soundFont: SoundFont, editing: Bool) -> IdentifiedArrayOf<PresetsListSection.State> {
  let grouping = 10
  let presets = editing ? soundFont.allPresets : soundFont.presets
  return .init(uniqueElements: presets.indices.chunks(ofCount: grouping).map { range in
    PresetsListSection.State(section: range.lowerBound, presets: presets[range])
  })
}

extension PresetsList {

  private func editPreset(_ state: inout State, preset: Preset) -> Effect<Action> {
    state.destination = .edit(PresetEditor.State(preset: preset))
    return .none
  }

  private func fetchPresets(_ state: inout State) -> Effect<Action> {
    guard let soundFont = state.soundFont else {
      state.sections = []
      state.editingVisibility = false
      return .none
    }
    state.sections = generatePresetSections(soundFont: soundFont, editing: state.editingVisibility)
    return .none
  }

  private func hidePreset(_ state: inout State, preset: Preset) -> Effect<Action> {
    guard let soundFont = state.soundFont else { fatalError("unexpected nil soundFont") }
    var newActive: Preset.ID? = preset.id
    if preset.id == activeState.activePresetId {
      let presets = soundFont.presets
      if let found = (0..<preset.index).last(where: { presets[$0].visible }) {
        newActive = presets[found].id
      } else if let found = ((preset.index + 1)..<presets.count).first(where: { presets[$0].visible }) {
        newActive = presets[found].id
      } else {
        newActive = nil
      }
    }

    var preset = preset
    _ = try? database.write {
      try preset.updateChanges($0) {
        $0.visible = false
      }
    }

    if preset.id == activeState.activePresetId && newActive != preset.id {
      setActivePresetId(&state, newActive)
    }

    return .run { send in
      await send(.fetchPresets)
    }.animation(.default)
  }

  private func monitorSelectedSoundFont() -> Effect<Action> {
    return .publisher {
      $activeState.selectedSoundFontId.publisher.map {
        return Action.selectedSoundFontIdChanged($0) }
    }.cancellable(id: pubisherCancelId)
  }

  private func selectPreset(_ state: inout State, preset: Preset) -> Effect<Action> {
    $activeState.withLock {
      $0.activePresetId = preset.id
      $0.activeSoundFontId = preset.soundFontId
    }
    return .none
  }

  private func setActivePresetId(_ state: inout State, _ presetId: Preset.ID?) {
    $activeState.withLock {
      $0.activePresetId = presetId
    }
  }

  private func setSoundFont(_ state: inout State, soundFontId: SoundFont.ID?) -> Effect<Action> {
    guard state.soundFont?.id != soundFontId else { return .none }
    state.editingVisibility = false
    @Dependency(\.defaultDatabase) var database
    guard let soundFontId else {
      state.soundFont = nil
      state.sections = []
      return .none.animation(.default)
    }

    let soundFont = try? database.read({ try SoundFont.fetchOne($0, id: soundFontId) })
    state.soundFont = soundFont
    return fetchPresets(&state)
  }

  private func toggleEditMode(_ state: inout State) -> Effect<Action> {
    state.editingVisibility.toggle()
    return fetchPresets(&state)
  }

  private func updatePreset(_ state: inout State) -> Effect<Action> {
    guard case let Destination.State.edit(editorState)? = state.destination else { return .none }
    state.update(preset: editorState.preset)
    return fetchPresets(&state)
  }
}

public struct PresetsListView: View {
  @Bindable internal var store: StoreOf<PresetsList>

  public init(store: StoreOf<PresetsList>) {
    self.store = store
  }

  public var body: some View {
    List {
      ForEach(store.scope(state: \.sections, action: \.sections), id: \.id) { rowStore in
        PresetsListSectionView(store: rowStore)
      }
    }
    .listStyle(.plain)
    .onAppear {
      store.send(.onAppear)
    }
    .sheet(item: $store.scope(state: \.destination?.edit, action: \.destination.edit)) {
      PresetEditorView(store: $0)
    }
    .navigationTitle("Presets")
    .environment(\.editMode, .constant(store.editingVisibility ? EditMode.active : .inactive))
    .toolbar {
      Button {
        store.send(.toggleEditMode, animation: .default)
      } label: {
        if store.state.editingVisibility {
          Text("Done")
            .foregroundStyle(.red)
        } else {
          Image(systemName: "checklist")
        }
      }
      Button {
      } label: {
        Image(systemName: "magnifyingglass")
      }
    }
  }
}

private extension DatabaseWriter where Self == DatabaseQueue {
  static var previewDatabase: Self {
    let databaseQueue = try! DatabaseQueue()
    try! databaseQueue.migrate()
    try! databaseQueue.write { db in
      for font in SF2ResourceFileTag.allCases {
        _ = try? SoundFont.make(db, builtin: font)
      }
    }

    let presets = try! databaseQueue.read { try! Preset.fetchAll($0) }
    print(presets.count)

    @Shared(.activeState) var activeState
    $activeState.withLock {
      $0.activePresetId = presets[0].id
      $0.activeSoundFontId = presets[0].soundFontId
      $0.selectedSoundFontId = presets[0].soundFontId
    }

    return databaseQueue
  }
}

extension PresetsListView {

  static var preview: some View {
    let _ = prepareDependencies { $0.defaultDatabase = .previewDatabase }
    @Dependency(\.defaultDatabase) var db
    let soundFonts = try! db.read { try! SoundFont.orderByPrimaryKey().fetchAll($0) }

    return VStack {
      NavigationStack {
        PresetsListView(store: Store(initialState: .init(soundFont: soundFonts[0])) { PresetsList() })
      }
    }
  }

  static var previewEditing: some View {
    let _ = prepareDependencies { $0.defaultDatabase = .previewDatabase }
    @Dependency(\.defaultDatabase) var db
    let soundFonts = try! db.read { try! SoundFont.orderByPrimaryKey().fetchAll($0) }

    return VStack {
      NavigationStack {
        PresetsListView(store: Store(initialState: .init(soundFont: soundFonts[0], editingVisibility: true)) {
          PresetsList()
        })
      }
    }
  }
}

#Preview {
  PresetsListView.preview
}
