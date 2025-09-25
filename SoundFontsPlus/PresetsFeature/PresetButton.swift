// Copyright © 2025 Brad Howes. All rights reserved.

import ComposableArchitecture
import SwiftNavigation
import SwiftUI
import Tagged

@Reducer
public struct PresetButton {

  @Reducer(state: .equatable)
  public enum Destination: Equatable {
    case alert(AlertState<Alert>)

    @CasePathable
    public enum Alert {
      case deleteFavoriteConfirmed
      case hidePresetConfirmed
    }
  }

  @ObservableState
  public struct State: Equatable, Identifiable {
    @Presents var destination: Destination.State?
    public var id: Preset.ID { preset.id }
    var preset: Preset

    public init(preset: Preset) {
      self.preset = preset
    }
  }

  public enum Action {
    case buttonTapped
    case delegate(Delegate)
    case deleteFavoriteButtonTapped
    case destination(PresentationAction<Destination.Action>)
    case editButtonTapped
    case favoriteButtonTapped
    case hidePresetButtonTapped
    case longPressGestureFired
    case toggleVisibility

    @CasePathable
    public enum Delegate {
      case createFavorite(Preset)
      case deleteFavorite(Preset)
      case editPreset(Preset)
      case hidePreset(Preset)
      case selectPreset(Preset)
    }
  }

  @Shared(.confirmPresetHiding) var confirmPresetHiding

  public var body: some ReducerOf<Self> {
    Reduce<State, Action> { state, action in
      switch action {

      case .buttonTapped:
        return .send(.delegate(.selectPreset(state.preset)))

      case .delegate:
        return .none

      case .deleteFavoriteButtonTapped:
        return deleteFavoriteButtonTapped(&state)

      case .destination(.presented(.alert(.deleteFavoriteConfirmed))):
        return deleteFavoriteConfirmed(&state)

      case .destination(.presented(.alert(.hidePresetConfirmed))):
        return hidePresetConfirmed(&state)

      case .destination:
        return .none

      case .editButtonTapped:
        return .send(.delegate(.editPreset(state.preset)))

      case .favoriteButtonTapped:
        return .send(.delegate(.createFavorite(state.preset)))

      case .hidePresetButtonTapped:
        return hidePresetButtonTapped(&state)

      case .longPressGestureFired:
        return .send(.delegate(.editPreset(state.preset)))

      case .toggleVisibility:
        state.preset.toggleVisibility()
        return .none
      }
    }
    .ifLet(\.destination, action: \.destination)
  }

  public init() {}
}

extension PresetButton.Destination.State: _EphemeralState {
  public typealias Action = Alert
}

extension PresetButton {

  private func deleteFavoriteConfirmed(_ state: inout State) -> Effect<Action> {
    .send(.delegate(.deleteFavorite(state.preset)))
  }

  private func hidePresetConfirmed(_ state: inout State) -> Effect<Action> {
    // $confirmPresetHiding.withLock { $0 = false }
    return .send(.delegate(.hidePreset(state.preset)))
  }

  private func deleteFavoriteButtonTapped(_ state: inout State) -> Effect<Action> {
    state.destination = .alert(
      .confirmDeleteFavorite(action: .deleteFavoriteConfirmed, displayName: state.preset.displayName)
    )
    return .none
  }

  private func hidePresetButtonTapped(_ state: inout State) -> Effect<Action> {
    if confirmPresetHiding {
      state.destination = .alert(
        .confirmHidePreset(action: .hidePresetConfirmed, displayName: state.preset.displayName)
      )
      return .none
    }
    return .send(.delegate(.hidePreset(state.preset)))
  }
}

extension AlertState {
  static func confirmHidePreset(action: Action, displayName: String) -> Self {
    Self {
      TextState("Hide '\(displayName)'?")
    } actions: {
      ButtonState(action: action) { TextState("Hide") }
      ButtonState(role: .cancel) { TextState("Cancel") }
    } message: {
      TextState(
"""
Hiding a preset will keep it from appearing in the list of presets. \
You can restore visibility via the preset visibility button in the toolbar.
"""
      )
    }
  }

  static func confirmDeleteFavorite(action: Action, displayName: String) -> Self {
    Self {
      TextState("Delete '\(displayName)'?")
    } actions: {
      ButtonState(role: .destructive, action: action) { TextState("Delete") }
      ButtonState(role: .cancel) { TextState("Cancel") }
    } message: {
      TextState(
"""
Deleting a favorite cannot be undone.
"""
      )
    }
  }
}

public struct PresetButtonView: View {
  @Bindable private var store: StoreOf<PresetButton>
  @Shared(.activeState) var activeState
  @Environment(\.editMode) private var editMode
  private var isFavorite: Bool { store.preset.kind == .favorite }
  private var isEditing: Bool { editMode?.wrappedValue == .active }

  public init(store: StoreOf<PresetButton>) {
    self.store = store
  }

  var state: IndicatorModifier.State {
    if activeState.activeSoundFontId == store.preset.soundFontId && activeState.activePresetId == store.preset.id {
      return .active
    }
    return .none
  }

  public var body: some View {
    Group {
      if isEditing {
        editVisibilityButton
          .transition(.opacity)
      } else {
        normalButton
          .transition(.opacity)
          .animation(.default, value: isEditing)
          .id(store.preset.id)
          .simultaneousGesture(
            LongPressGesture(minimumDuration: 1.0)
              .onEnded { _ in store.send(.longPressGestureFired) }
          )
      }
    }
    .animation(.default, value: isEditing)
  }

  public var normalButtonText: some View {
    PresetNameView(preset: store.preset)
      .indicator(state)
  }

  public var normalButton: some View {
    Button {
      store.send(.buttonTapped, animation: .default)
    } label: {
      normalButtonText
    }
    .listRowSeparator(.hidden)
    .alert($store.scope(state: \.destination?.alert, action: \.destination.alert))
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
        Image(systemName: store.preset.isFavorite ? "document.on.document.fill" : "star")
          .tint(.yellow)
      }
    }
    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
      if store.preset.isFavorite {
        Button {
          store.send(.deleteFavoriteButtonTapped, animation: .default)
        } label: {
          Image(systemName: "trash")
            .tint(.red)
        }
      } else {
        Button {
          store.send(.hidePresetButtonTapped, animation: .default)
        } label: {
          Image(systemName: "eye.slash")
            .tint(.gray)
        }
      }
    }
  }

  private var editVisibilityButton: some View {
    Button {
      store.send(.toggleVisibility, animation: .default)
    } label: {
      HStack {
        Image(systemName: store.preset.kind == .hidden ? "circle" : "inset.filled.circle")
          .foregroundStyle(Color.gold)
          .animation(.smooth, value: store.preset.kind)
          .frame(maxWidth: 24)
        Text(store.preset.displayName)
          .indicator(.none)
      }
    }
    .listRowSeparator(.hidden)
  }
}

extension PresetButtonView {
  static var preview: some View {
    var presets = prepareDependencies {
      // swiftlint:disable:next force_try
      $0.defaultDatabase = try! appDatabase()
      return Operations.presets
    }

    // swiftlint:disable:next force_unwrapping
    if let clone = presets.last!.clone() {
      presets.append(clone)
    }

    return VStack {
      Text("Normal")
      List {
        PresetButtonView(store: Store(initialState: .init(preset: presets[0])) { PresetButton() })
        PresetButtonView(store: Store(initialState: .init(preset: presets[1])) { PresetButton() })
        // swiftlint:disable:next force_unwrapping
        PresetButtonView(store: Store(initialState: .init(preset: presets.last!)) { PresetButton() })
      }
      .listStyle(.plain)
      .environment(\.editMode, .constant(.inactive))

      Text("Edit Mode")
      List {
        PresetButtonView(store: Store(initialState: .init(preset: presets[0])) { PresetButton() })
        PresetButtonView(store: Store(initialState: .init(preset: presets[1])) { PresetButton() })
        PresetButtonView(store: Store(initialState: .init(preset: presets[2])) { PresetButton() })
      }
      .listStyle(.plain)
      .environment(\.editMode, .constant(.active))
    }
  }
}

#Preview {
  PresetButtonView.preview
}
