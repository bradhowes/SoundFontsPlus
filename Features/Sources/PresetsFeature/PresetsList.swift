// Copyright © 2024 Brad Howes. All rights reserved.

import Algorithms
import ComposableArchitecture
import SwiftData
import SwiftUI
import Models

@Reducer
public struct PresetsList {

  @Reducer
  public enum Destination {
    case edit(PresetEditor)
  }

  @ObservableState
  public struct State: Equatable {
    @Presents var destination: Destination.State?
    var rows: IdentifiedArrayOf<PresetsListSection.State>
    @Shared(.activeState) var activeState = .init()

    public init(presets: [PresetModel]) {
      let grouping = 10
      self.rows = .init(uniqueElements: presets.indices.chunks(ofCount: grouping).map { range in
        PresetsListSection.State(section: range.lowerBound, presets: Array(presets[range]))
      })
    }
  }

  public enum Action {
    case destination(PresentationAction<Destination.Action>)
    case rows(IdentifiedActionOf<PresetsListSection>)
  }

  public init() {}

  public var body: some ReducerOf<Self> {
    Reduce<State, Action> { state, action in
      switch action {

      case .destination(.dismiss):
        return .none

      case .destination:
        return .none

      case let .rows(.element(id: _, action: .rows(.element(id: _, action: .delegate(.editPreset(preset)))))):
        state.destination = .edit(PresetEditor.State(preset: preset))
        return .none

      case let .rows(.element(id: _, action: .rows(.element(id: _, action: .delegate(.selectPreset(preset)))))):
        state.activeState.setActivePresetKey(preset.key)
        return .none

      case .rows:
        return .none
      }
    }
    .forEach(\.rows, action: \.rows) {
      PresetsListSection()
    }
    .ifLet(\.$destination, action: \.destination)
    ._printChanges()
  }
}

extension PresetsList.Destination.State: Equatable {}

extension PresetsList {

  private func hidePreset(_ state: inout State, key: PresetModel.Key) {
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
    .sheet(
      item: $store.scope(state: \.destination?.edit, action: \.destination.edit)
    ) { editorStore in
      PresetEditorView(store: editorStore)
    }
  }
}

extension PresetsListView {
  static var preview: some View {
    let soundFonts = try! SoundFontModel.tagged(with: TagModel.Ubiquitous.all.key)
    return VStack {
      PresetsListView(store: Store(initialState: .init(presets: soundFonts[0].orderedPresets)) { PresetsList() })
    }
  }
}

#Preview {
  PresetsListView.preview
}

extension View {
  func sectionHeaderStyle() -> some View {
    self
      .foregroundColor(.indigo)
    // plus whatever other styling you want
  }
}
