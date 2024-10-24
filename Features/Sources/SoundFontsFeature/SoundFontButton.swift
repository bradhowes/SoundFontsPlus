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
    public var id: SoundFontModel.Key { key }
    public let key: SoundFontModel.Key
    public let displayName: String
    public let canDelete: Bool

    @Shared(.activeState) var activeState = ActiveState()

    public init(soundFont: SoundFontModel) {
      self.key = soundFont.key
      self.displayName = soundFont.displayName
      self.canDelete = soundFont.location.isBuiltin == false
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
    case deleteSoundFont(key: SoundFontModel.Key)
    case editSoundFont(key: SoundFontModel.Key)
    case selectSoundFont(key: SoundFontModel.Key)
  }

  public var body: some ReducerOf<Self> {
    Reduce<State, Action> { state, action in
      switch action {
      case .buttonTapped: return .send(.delegate(.selectSoundFont(key: state.key)))
      case .confirmedDeletion: return .send(.delegate(.deleteSoundFont(key: state.key)))
      case .delegate: return .none
      case .editButtonTapped: return .send(.delegate(.editSoundFont(key: state.key)))
      case .longPressGestureFired: return .send(.delegate(.editSoundFont(key: state.key)))
      }
    }
  }

  public init() {}
}

struct SoundFontButtonView: View {
  private var store: StoreOf<SoundFontButton>
  @State var confirmingDeletion: Bool = false

  var displayName: String { store.displayName }
  var key: SoundFontModel.Key { store.key }
  var canDelete: Bool { store.canDelete }
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
        .font(Font.custom("Eurostile", size: 20))
        .indicator(state)
    }
    .onCustomLongPressGesture {
      store.send(.longPressGestureFired, animation: .default)
    }
    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
      Button {
        confirmingDeletion = true
      } label: {
        Image(systemName: "trash")
          .tint(.gray)
      }
    }
    .confirmationDialog(
      "Are you sure you want to delete \"\(store.displayName)\"?\n\n" +
      "You will lose all preset customizations.",
      isPresented: $confirmingDeletion,
      titleVisibility: .visible
    ) {
      Button("Confirm", role: .destructive) {
        store.send(.confirmedDeletion, animation: .default)
      }
      Button("Cancel", role: .cancel) {
        confirmingDeletion = false
      }
    }
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
