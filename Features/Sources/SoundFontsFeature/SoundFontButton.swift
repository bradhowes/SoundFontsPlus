// Copyright © 2024 Brad Howes. All rights reserved.

import ComposableArchitecture
import SwiftUI
import Models
import SwiftUISupport
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

  public enum Action {
    case buttonTapped
    case confirmedDeletion
    case editButtonTapped
    case delegate(Delegate)
    case longPressGestureFired
  }

  @CasePathable
  public enum Delegate {
    case deleteSoundFont
    case editSoundFont
    case selectSoundFont
  }

  public var body: some ReducerOf<Self> {
    Reduce<State, Action> { state, action in
      switch action {
      case .buttonTapped: return .send(.delegate(.selectSoundFont))
      case .confirmedDeletion: return .send(.delegate(.deleteSoundFont))
      case .delegate: return .none
      case .editButtonTapped: return .send(.delegate(.editSoundFont))
      case .longPressGestureFired: return .send(.delegate(.editSoundFont))
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
  var canDelete: Bool { store.soundFont.location.isBuiltin == false }
  var state: IndicatorModifier.State {
    if store.activeState.activeSoundFontKey == key {
      return .active
    }
    return store.activeState.selectedSoundFontKey == key ? .selected : .none
  }

  init(store: StoreOf<SoundFontButton>) {
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
      "Are you sure you want to delete \(displayName)? You will lose all preset customizations.",
      enabled: canDelete,
      showingConfirmation: $confirmingDeletion
    ) {
      store.send(.confirmedDeletion) }
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
