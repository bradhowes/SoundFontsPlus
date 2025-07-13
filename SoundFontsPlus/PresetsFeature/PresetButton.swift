// Copyright © 2025 Brad Howes. All rights reserved.

import ComposableArchitecture
import SwiftNavigation
import SwiftUI
import Tagged

@Reducer
public struct PresetButton {

  @ObservableState
  public struct State: Equatable, Identifiable {
    public var id: Preset.ID { preset.id }
    public var preset: Preset
    @Presents public var confirmationDialog: ConfirmationDialogState<Action.ConfirmationDialog>?

    public init(preset: Preset) {
      self.preset = preset
    }
  }

  public enum Action: Equatable {
    case buttonTapped
    case confirmationDialog(PresentationAction<ConfirmationDialog>)
    case delegate(Delegate)
    case editButtonTapped
    case favoriteButtonTapped
    case hideOrDeleteButtonTapped
    case longPressGestureFired
    case toggleVisibility

    @CasePathable
    public enum ConfirmationDialog {
      case cancelButtonTapped
      case hideButtonTapped
    }
  }

  @CasePathable
  public enum Delegate: Equatable {
    case createFavorite(Preset)
    case editPreset(Preset)
    case hideOrDeletePreset(Preset)
    case selectPreset(Preset)
  }

  @Shared(.stopConfirmingPresetHiding) var stopConfirmingPresetHiding

  public var body: some ReducerOf<Self> {
    Reduce<State, Action> { state, action in
      switch action {
      case .buttonTapped: return .send(.delegate(.selectPreset(state.preset)))
      case .confirmationDialog(.presented(.hideButtonTapped)):
        return .send(.delegate(.hideOrDeletePreset(state.preset))).animation(.default)
      case .confirmationDialog: return .none
      case .delegate: return .none
      case .editButtonTapped: return .send(.delegate(.editPreset(state.preset)))
      case .favoriteButtonTapped: return .send(.delegate(.createFavorite(state.preset)))
      case .hideOrDeleteButtonTapped: return .send(.delegate(.hideOrDeletePreset(state.preset)))
      case .longPressGestureFired: return .send(.delegate(.editPreset(state.preset)))
      case .toggleVisibility: return toggleVisibility(&state)
      }
    }
    .ifLet(\.$confirmationDialog, action: \.confirmationDialog)
  }

  public init() {}
}

extension PresetButton {

  static func hideConfirmationDialogState(displayName: String) -> ConfirmationDialogState<Action.ConfirmationDialog> {
    ConfirmationDialogState {
      TextState("Hide \(displayName)?")
    } actions: {
      ButtonState(role: .cancel) { TextState("Cancel") }
      ButtonState(action: .hideButtonTapped) { TextState("Hide") }
    } message: {
      TextState(
        "Hide \(displayName)?\n\n" +
        "Hiding a preset will keep it from appearing in the list of presets. " +
        "You can restore them via the visibility button in the toolbar."
      )
    }
  }

  private func toggleVisibility(_ state: inout State) -> Effect<Action> {
    state.preset.toggleVisibility()
    return .none
  }
}

extension SharedKey where Self == AppStorageKey<Bool>.Default {
  public static var stopConfirmingPresetHiding: Self {
    Self[.appStorage("stopConfirmingPresetHiding"), default: .init()]
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
            LongPressGesture()
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
    .confirmationDialog($store.scope(state: \.confirmationDialog, action: \.confirmationDialog))
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
      Button {
        store.send(.hideOrDeleteButtonTapped, animation: .default)
      } label: {
        if store.preset.isFavorite {
          Image(systemName: "trash")
            .tint(.red)
        } else {
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
      List {
        PresetButtonView(store: Store(initialState: .init(preset: presets[0])) { PresetButton() })
        PresetButtonView(store: Store(initialState: .init(preset: presets[1])) { PresetButton() })
        // swiftlint:disable:next force_unwrapping
        PresetButtonView(store: Store(initialState: .init(preset: presets.last!)) { PresetButton() })
      }
      .listStyle(.plain)
      .environment(\.editMode, .constant(.inactive))

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
