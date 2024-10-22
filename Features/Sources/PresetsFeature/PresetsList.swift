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
    let soundFont: SoundFontModel
    var rows: IdentifiedArrayOf<PresetsListSection.State>
    @Shared(.activeState) var activeState = .init()

    public init(soundFont: SoundFontModel) {
      self.soundFont = soundFont
      self.rows = generatePresetSections(soundFont: soundFont)
    }
  }

  public enum Action {
    case changeVisibility
    case destination(PresentationAction<Destination.Action>)
    case rows(IdentifiedActionOf<PresetsListSection>)
  }

  public init() {}

  public var body: some ReducerOf<Self> {
    Reduce<State, Action> { state, action in
      switch action {

      case .changeVisibility:
        return .none

      case .destination(.dismiss):
        return .none

      case .destination:
        return .none

      case let .rows(.element(id: _, action: .rows(.element(id: _, action: .delegate(.editPreset(preset)))))):
        state.destination = .edit(PresetEditor.State(preset: preset))
        return .none

      case let .rows(.element(id: _, action: .rows(.element(id: _, action: .delegate(.hidePreset(preset)))))):
        hidePreset(&state, preset: preset)
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
  }
}

extension PresetsList.Destination.State: Equatable {}

private func generatePresetSections(soundFont: SoundFontModel) -> IdentifiedArrayOf<PresetsListSection.State> {
  let grouping = 10
  let presets = soundFont.orderedVisiblePresets
  return .init(uniqueElements: presets.indices.chunks(ofCount: grouping).map { range in
    PresetsListSection.State(section: range.lowerBound, presets: Array(presets[range]))
  })
}

extension PresetsList {

  private func hidePreset(_ state: inout State, preset: PresetModel) {
    @Dependency(\.modelContextProvider) var context
    if preset.key == state.activeState.activePresetKey {
      // Locate the first preset that is not hidden to become the active one
      let presets = state.soundFont.orderedVisiblePresets
      if let found = (0..<preset.key.rawValue).last(where: { presets[$0].visible }) {
        print("before - \(found)")
        state.activeState.setActivePresetKey(presets[found].key)
      } else if let found = ((preset.key.rawValue + 1)..<presets.count).first(where: { presets[$0].visible }) {
        print("after - \(found)")
        state.activeState.setActivePresetKey(presets[found].key)
      } else {
        print("nothing found")
        state.activeState.setActivePresetKey(.init(-1))
      }
    }

    preset.visible = false
    state.rows = generatePresetSections(soundFont: state.soundFont)
    do {
      try context.save()
    } catch {
      print("failed to save preset change: \(error)")
    }
  }
}

public struct PresetsListView: View {
  @Bindable private var store: StoreOf<PresetsList>

  public init(store: StoreOf<PresetsList>) {
    self.store = store
  }

  public var body: some View {
    VStack(spacing: 8.0) {
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
      HStack{
        Spacer()
        Button {
          store.send(.changeVisibility)
        } label: {
          Label("", systemImage: "checklist")
        }
      }
    }.padding(.bottom, 16.0)
  }
}

extension PresetsListView {
  static var preview: some View {
    let soundFonts = try! SoundFontModel.tagged(with: TagModel.Ubiquitous.all.key)
    return VStack {
      PresetsListView(store: Store(initialState: .init(soundFont: soundFonts[0])) { PresetsList() })
    }
  }
}

#Preview {
  PresetsListView.preview
}
