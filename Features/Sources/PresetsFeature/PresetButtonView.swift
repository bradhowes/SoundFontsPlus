// Copyright © 2024 Brad Howes. All rights reserved.

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
    @Shared(.activeState) var activeState = ActiveState()

    public init(preset: PresetModel) {
      self.preset = preset
    }
  }

  public enum Action {
    case buttonTapped
    case confirmedHiding
    case delegate(Delegate)
    case hideButtonTapped
    case longPressGestureFired
  }

  @CasePathable
  public enum Delegate {
    case editPreset
    case hidePreset
    case selectPreset
    case createFavorite
  }

  public var body: some ReducerOf<Self> {
    Reduce<State, Action> { state, action in
      switch action {
      case .buttonTapped: return .send(.delegate(.selectPreset))
      case .confirmedHiding: return .send(.delegate(.hidePreset))
      case .delegate: return .none
      case .hideButtonTapped: return .none
      case .longPressGestureFired: return .send(.delegate(.editPreset))
      }
    }
  }

  public init() {}
}

struct PresetButtonView: View {
  private var store: StoreOf<PresetButton>
  @State var confirmingHiding: Bool = false

  var displayName: String { store.preset.displayName }
  var key: PresetModel.Key { store.preset.key }
  var state: IndicatorModifier.State {
    if store.activeState.activePresetKey == key {
      return .active
    }
    return store.activeState.activePresetKey == key ? .active : .none
  }

  init(store: StoreOf<PresetButton>) {
    self.store = store
  }

  public var body: some View {
    Button {
      store.send(.buttonTapped, animation: .default)
    } label: {
      Text(displayName)
        .indicator(state)
    }
    .onCustomLongPressGesture {
      store.send(.longPressGestureFired, animation: .default)
    }
    .swipeActionWithConfirmation(
      "Are you sure you want to hide \(store.preset.displayName)?" +
      "It will no longer be visible. You can restore visibility using the edit visibility control.",
      enabled: true,
      showingConfirmation: $confirmingHiding
    ) {
      store.send(.confirmedHiding)
    }
  }
}

//#Preview {
//  let soundFonts = [
//    try! Mock.makeSoundFont(name: "First One", presetNames: ["A", "B", "C"], tags: []),
//    try! Mock.makeSoundFont(name: "Second", presetNames: ["A", "B", "C"], tags: []),
//    try! Mock.makeSoundFont(name: "Third", presetNames: ["A", "B", "C"], tags: []),
//  ]
//  List {
//    SoundFontButtonView(store: Store(initialState: .init(soundFont: soundFonts[0])) { SoundFontButton() })
//    SoundFontButtonView(store: Store(initialState: .init(soundFont: soundFonts[1])) { SoundFontButton() })
//    SoundFontButtonView(store: Store(initialState: .init(soundFont: soundFonts[2])) { SoundFontButton() })
//  }
//}
