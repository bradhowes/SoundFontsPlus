// Copyright © 2025 Brad Howes. All rights reserved.

import Algorithms
import ComposableArchitecture
import GRDB
import SF2ResourceFiles
import SwiftUI
import Models

@Reducer
public struct PresetsList {

  @Reducer(state: .equatable, .sendable)
  public enum Destination {
    case edit(PresetEditor)
  }

  @ObservableState
  public struct State: Equatable {
    @Presents var destination: Destination.State?
    var soundFont: SoundFont?
    var sections: IdentifiedArrayOf<PresetsListSection.State>

    public init(soundFont: SoundFont?) {
      self.soundFont = soundFont
      if let soundFont {
        self.sections = generatePresetSections(soundFont: soundFont, editing: false)
      } else {
        self.sections = []
      }
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

  public enum Action {
    case destination(PresentationAction<Destination.Action>)
    case fetchPresets(Bool)
    case onAppear
    case sections(IdentifiedActionOf<PresetsListSection>)
    case selectedSoundFontIdChanged(SoundFont.ID?)
    case stop
  }

  public init() {}

  @Shared(.activeState) var activeState
  private let pubisherCancelId = "selectedSoundFontChangedPublisher"

  public var body: some ReducerOf<Self> {
    Reduce<State, Action> { state, action in
      switch action {

      case .destination(.presented(.edit(.acceptButtonTapped))):
        // Update the row with the preset that was edited.
        guard case let Destination.State.edit(editorState)? = state.destination else { return .none }
        state.update(preset: editorState.preset)
        return .none

      case .destination:
        return .none

      case .fetchPresets(let editing):
        return fetchPresets(&state, soundFontId: activeState.activeSoundFontId, editing: editing)

      case .onAppear:
        return .publisher {
          $activeState.selectedSoundFontId.publisher.map {
            return Action.selectedSoundFontIdChanged($0) }
        }.cancellable(id: pubisherCancelId)

      case let .sections(.element(id: _, action: .rows(.element(id: _, action: .delegate(.editPreset(preset)))))):
        state.destination = .edit(PresetEditor.State(preset: preset))
        return .none

      case let .sections(.element(id: _, action: .rows(.element(id: _, action: .delegate(.hidePreset(preset)))))):
        hidePreset(&state, preset: preset)
        return .none

      case let .sections(.element(id: _, action: .rows(.element(id: _, action: .delegate(.selectPreset(preset)))))):
        $activeState.withLock {
          $0.activePresetId = preset.id
          $0.activeSoundFontId = preset.soundFontId
        }
        return .none

      case .sections:
        return .none

      case .selectedSoundFontIdChanged(let soundFontId):
        return fetchPresets(&state, soundFontId: soundFontId, editing: false)

      case .stop: return .cancel(id: pubisherCancelId)
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
    PresetsListSection.State(section: range.lowerBound, presets: Array(presets[range]))
  })
}

extension PresetsList {

  private func fetchPresets(_ state: inout State, soundFontId: SoundFont.ID?, editing: Bool) -> Effect<Action> {
    guard let soundFontId else {
      state.soundFont = nil
      state.sections = []
      return .none
    }

    @Dependency(\.defaultDatabase) var database
    do {
      let soundFont = try database.read { try SoundFont.fetchOne($0, id: soundFontId) }
      if let soundFont {
        state.soundFont = soundFont
        state.sections = generatePresetSections(soundFont: soundFont, editing: editing)
      } else {
        state.sections = []
      }
    } catch {
      state.sections = []
      print("failed to fetch sound font key \(soundFontId)")
    }

    return .none
  }

  private func setActivePresetId(_ state: inout State, _ presetId: Preset.ID?) {
    $activeState.withLock {
      $0.activePresetId = presetId
    }
  }

  private func hidePreset(_ state: inout State, preset: Preset) {
    guard let soundFont = state.soundFont else {
      fatalError("unexpected nil soundFont")
    }
    @Dependency(\.defaultDatabase) var database

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
    do {
      _ = try database.write {
        try preset.updateChanges($0) {
          $0.visible = false
        }
      }
    } catch {
    }

    state.sections = generatePresetSections(soundFont: soundFont, editing: false)

    if newActive != activeState.activePresetId {
      setActivePresetId(&state, newActive)
    }
  }
}

public struct PresetsListView: View {
  @Bindable private var store: StoreOf<PresetsList>
  @Environment(\.editMode) private var editMode

  public init(store: StoreOf<PresetsList>) {
    self.store = store
  }

  public var body: some View {
    List {
      ForEach(store.scope(state: \.sections, action: \.sections), id: \.id) { rowStore in
        PresetsListSectionView(store: rowStore)
      }
    }
    .listSectionSpacing(.custom(-14.0))
    .onAppear {
      store.send(.onAppear)
    }
    .onChange(of: editMode?.wrappedValue.isEditing) {
      store.send(.fetchPresets(editMode?.wrappedValue == EditMode.active), animation: .default)
    }
    .sheet(
      item: $store.scope(state: \.destination?.edit, action: \.destination.edit)
    ) { editorStore in
      PresetEditorView(store: editorStore)
    }
    .navigationTitle("Presets")
    .toolbar {
      Button {
      } label: {
        Image(systemName: "checklist")
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
        _ = try! SoundFont.make(db, builtin: font)
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
      EditButton()
      PresetsListView(store: Store(initialState: .init(soundFont: soundFonts[0])) {
        PresetsList()
      })
    }
  }
}

#Preview {
  PresetsListView.preview
}
