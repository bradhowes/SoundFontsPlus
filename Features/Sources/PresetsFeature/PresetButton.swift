// Copyright © 2025 Brad Howes. All rights reserved.

import ComposableArchitecture
import SwiftUI
import Models
import SwiftUISupport
import Tagged

@Reducer
public struct PresetButton {

  @ObservableState
  public struct State: Equatable, Identifiable {
    public var preset: PresetModel
    public var id: PresetModel.Key { preset.key }
    @Shared(.activeState) var activeState

    public init(preset: PresetModel) {
      self.preset = preset
    }
  }

  public enum Action {
    case buttonTapped
    case confirmedHiding
    case delegate(Delegate)
    case editButtonTapped
    case favoriteButtonTapped
    case hideButtonTapped
    case longPressGestureFired
  }

  @CasePathable
  public enum Delegate {
    case createFavorite(PresetModel)
    case editPreset(PresetModel)
    case hidePreset(PresetModel)
    case selectPreset(PresetModel)
  }

  public var body: some ReducerOf<Self> {
    Reduce<State, Action> { state, action in
      switch action {
      case .buttonTapped: return .send(.delegate(.selectPreset(state.preset)))
      case .confirmedHiding: return .send(.delegate(.hidePreset(state.preset)))
      case .delegate: return .none
      case .editButtonTapped: return .send(.delegate(.editPreset(state.preset)))
      case .favoriteButtonTapped: return .send(.delegate(.createFavorite(state.preset)))
      case .hideButtonTapped: return .none
      case .longPressGestureFired: return .send(.delegate(.editPreset(state.preset)))
      }
    }
  }

  public init() {}
}

struct PresetButtonView: View {
  private var store: StoreOf<PresetButton>
  @State var confirmingHiding: Bool = false

  var displayName: String { store.preset.displayName }
  var soundFontKey: SoundFontModel.Key? { store.preset.owner?.key }
  var key: PresetModel.Key { store.preset.key }
  var state: IndicatorModifier.State {
    if store.activeState.activeSoundFontKey == soundFontKey && store.activeState.activePresetKey == key {
      return .active
    }
    return .none
  }

  init(store: StoreOf<PresetButton>) {
    self.store = store
  }

  public var body: some View {
    Button {
      store.send(.buttonTapped, animation: .default)
    } label: {
      Text(displayName)
        .font(.buttonFont)
        .indicator(state)
    }
    .onCustomLongPressGesture {
      store.send(.longPressGestureFired, animation: .default)
    }
    .swipeActions(edge: .leading, allowsFullSwipe: false) {
      Button {
        store.send(.editButtonTapped, animation: .default)
      } label: {
        Image(systemName: "pencil")
          .tint(.cyan)
      }
      Button {
        store.send(.favoriteButtonTapped, animation: .default)
      } label: {
        Image(systemName: "star")
          .tint(.yellow)
      }
    }
    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
      Button {
        confirmingHiding = true
      } label: {
        Image(systemName: "eye.slash")
          .tint(.gray)
      }
    }
    .confirmationDialog(
      "Are you sure you want to hide \"\(store.preset.displayName)\" preset?\n\n" +
      "Once hidden It will no longer be visible here but you can restore visibility using the edit visibility control.",
      isPresented: $confirmingHiding,
      titleVisibility: .visible
    ) {
      Button("Confirm", role: .destructive) {
        store.send(.confirmedHiding, animation: .default)
      }
      Button("Cancel", role: .cancel) {
        confirmingHiding = false
      }
    }
  }
}

#Preview {
  let soundFonts = [
    try! Mock.makeSoundFont(name: "First One", presetNames: ["A", "B", "C"], tags: [])
  ]
  List {
    PresetButtonView(store: Store(initialState: .init(preset: soundFonts[0].orderedPresets[0])) { PresetButton() })
    PresetButtonView(store: Store(initialState: .init(preset: soundFonts[0].orderedPresets[1])) { PresetButton() })
    PresetButtonView(store: Store(initialState: .init(preset: soundFonts[0].orderedPresets[2])) { PresetButton() })
  }
}
