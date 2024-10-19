// Copyright © 2024 Brad Howes. All rights reserved.

import ComposableArchitecture
import SwiftUI
import Models
import Tagged

@Reducer
public struct SoundFontButton {

  @ObservableState
  public struct State: Equatable, Identifiable {
    public var soundFont: SoundFontModel
    public var id: SoundFontModel.Key { soundFont.key }
    @Shared(.activeState) var activeState = ActiveState()

    public init(soundFont: SoundFontModel) {
      self.soundFont = soundFont
    }
  }

  public enum Action: Sendable {
    case buttonTapped(key: SoundFontModel.Key)
  }

  public var body: some ReducerOf<Self> {
    Reduce<State, Action> { state, action in
      switch action {
      case .buttonTapped(let key):
        print("buttonTapped - \(key)")
        state.activeState.setSelectedSoundFontKey(key)
        return .none
      }
    }
  }

  public init() {}
}

struct SoundFontButtonView: View {
  private var store: StoreOf<SoundFontButton>
  @State var confirmingDeletion: Bool = false

  var displayName: String { store.soundFont.displayName }
  var key: SoundFontModel.Key { store.soundFont.key }

  var state: IndicatorModifier.State {
    print("activeState - \(store.activeState)")

    if store.activeState.activeSoundFontKey == key {
      print("\(key) - active")
      return .active
    }
    else if store.activeState.selectedSoundFontKey == key {
      print("\(key) - selected")
      return .selected
    }
    else {
      print("\(key) - none")
      return .none
    }
  }

  init(
    store: StoreOf<SoundFontButton>
  ) {
    self.store = store
  }

  public var body: some View {
    Button {
      store.send(.buttonTapped(key: key), animation: .default)
    } label: {
      Text(displayName)
        .indicator(state)
    }
    .swipeToDeleteSoundFont(
      enabled: false,
      showingConfirmation: $confirmingDeletion,
      key: key,
      name: displayName) {}
  }
}

#Preview {
  let soundFonts = [
    try! Mock.makeSoundFont(name: "First One", presetNames: ["A", "B", "C"], tags: []),
    try! Mock.makeSoundFont(name: "Second", presetNames: ["A", "B", "C"], tags: []),
    try! Mock.makeSoundFont(name: "Third", presetNames: ["A", "B", "C"], tags: []),
  ]
  List {
    SoundFontButtonView(store: Store(initialState: .init(soundFont: soundFonts[0])) { SoundFontButton() })
    SoundFontButtonView(store: Store(initialState: .init(soundFont: soundFonts[1])) { SoundFontButton() })
    SoundFontButtonView(store: Store(initialState: .init(soundFont: soundFonts[2])) { SoundFontButton() })
  }
}
