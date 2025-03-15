// Copyright © 2025 Brad Howes. All rights reserved.

import Algorithms
import ComposableArchitecture
import GRDB
import SF2ResourceFiles
import SwiftUI
import Models

@Reducer
public struct PresetsList {

  @Reducer
  public enum Destination {
    case edit(PresetEditor)
  }

  @ObservableState
  public struct State {
    @Presents var destination: Destination.State?
    let soundFont: SoundFont
    var rows: IdentifiedArrayOf<PresetsListSection.State>

    public init(soundFont: SoundFont) {
      self.soundFont = soundFont
      self.rows = generatePresetSections(soundFont: soundFont)
    }
  }

  public enum Action {
    case changeVisibility
    case destination(PresentationAction<Destination.Action>)
    case fetchSoundFonts
    case onAppear
    case rows(IdentifiedActionOf<PresetsListSection>)
    case selectedSoundFontIdChanged(SoundFont.ID?)
  }

  public init() {}

  @Shared(.activeState) var activeState

  public var body: some ReducerOf<Self> {
    Reduce<State, Action> { state, action in
      switch action {

      case .changeVisibility:
        return .none

      case .destination(.presented(.edit(.acceptButtonTapped))):
        // We should be able to just update the row that is being edited
        return fetchPresets(&state, key: activeState.activeSoundFontId)

      case .destination:
        return .none

      case .fetchSoundFonts:
        return fetchPresets(&state, key: activeState.activeSoundFontId)

      case .onAppear:
        return .publisher {
          $activeState.selectedSoundFontId.publisher.map {
            return Action.selectedSoundFontIdChanged($0) }
        }

      case let .rows(.element(id: _, action: .rows(.element(id: _, action: .delegate(.editPreset(preset)))))):
        state.destination = .edit(PresetEditor.State(preset: preset))
        return .none

      case let .rows(.element(id: _, action: .rows(.element(id: _, action: .delegate(.hidePreset(preset)))))):
        hidePreset(&state, preset: preset)
        return .none

      case let .rows(.element(id: _, action: .rows(.element(id: _, action: .delegate(.selectPreset(preset)))))):
        $activeState.withLock {
          $0.activePresetId = preset.id
          $0.activeSoundFontId = preset.soundFontId
        }
        return .none

      case .rows:
        return .none

      case .selectedSoundFontIdChanged(let key):
        return fetchPresets(&state, key: key)
      }
    }
    .forEach(\.rows, action: \.rows) {
      PresetsListSection()
    }
    .ifLet(\.$destination, action: \.destination)
  }
}

// extension PresetsList.Destination.State: Equatable {}

private func generatePresetSections(soundFont: SoundFont) -> IdentifiedArrayOf<PresetsListSection.State> {
  let grouping = 10
  let presets = soundFont.presets
  return .init(uniqueElements: presets.indices.chunks(ofCount: grouping).map { range in
    PresetsListSection.State(section: range.lowerBound, presets: Array(presets[range]))
  })
}

extension PresetsList {

  private func fetchPresets(_ state: inout State, key: SoundFont.ID?) -> Effect<Action> {
    guard let key else { return .none }
    @Dependency(\.defaultDatabase) var database
    do {
      let soundFont = try database.read { try SoundFont.fetchOne($0, id: key) }
      if let soundFont {
        state.rows = generatePresetSections(soundFont: soundFont)
      } else {
        state.rows = []
      }
    } catch {
      state.rows = []
      print("failed to fetch sound font key \(key)")
    }

    return .none
  }

  private func setActivePresetId(_ state: inout State, _ presetId: Preset.ID?) {
    $activeState.withLock {
      $0.activePresetId = presetId
    }
  }

  private func hidePreset(_ state: inout State, preset: Preset) {
    @Dependency(\.defaultDatabase) var database

    var newActive: Preset.ID? = preset.id
    if preset.id == activeState.activePresetId {
      let presets = state.soundFont.presets
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

    state.rows = generatePresetSections(soundFont: state.soundFont)

    if newActive != activeState.activePresetId {
      setActivePresetId(&state, newActive)
    }
  }
}

public struct PresetsListView: View {
  @Bindable private var store: StoreOf<PresetsList>

  public init(store: StoreOf<PresetsList>) {
    self.store = store
  }

  public var body: some View {
    List {
      ForEach(store.scope(state: \.rows, action: \.rows), id: \.id) { rowStore in
        PresetsListSectionView(store: rowStore)
      }
    }
    .listSectionSpacing(.custom(-14.0))
    .onAppear {
      store.send(.onAppear)
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
      PresetsListView(store: Store(initialState: .init(soundFont: soundFonts[0])) { PresetsList() })
    }
  }
}

#Preview {
  PresetsListView.preview
}
