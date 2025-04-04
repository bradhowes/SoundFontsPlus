// Copyright © 2025 Brad Howes. All rights reserved.

import ComposableArchitecture
import GRDB
import Models
import SF2ResourceFiles
import SwiftNavigation
import SwiftUI
import SwiftUISupport
import Tagged

@Reducer
public struct PresetButton {

  @ObservableState
  public struct State: Equatable, Identifiable {
    public var preset: Preset
    public var id: Preset.ID { preset.id }
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
    case hideButtonTapped
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
    case hidePreset(Preset)
    case selectPreset(Preset)
  }

  @Shared(.stopConfirmingPresetHiding) var stopConfirmingPresetHiding

  public var body: some ReducerOf<Self> {
    Reduce<State, Action> { state, action in
      switch action {
      case .buttonTapped: return .send(.delegate(.selectPreset(state.preset)))
      case .confirmationDialog(.presented(.hideButtonTapped)):
        return .send(.delegate(.hidePreset(state.preset))).animation(.default)
      case .confirmationDialog: return .none
      case .delegate: return .none
      case .editButtonTapped: return .send(.delegate(.editPreset(state.preset)))
      case .favoriteButtonTapped: return .send(.delegate(.createFavorite(state.preset)))
      case .hideButtonTapped: return hideButtonTapped(&state)
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

  private func hideButtonTapped(_ state: inout State) -> Effect<Action> {
    guard !stopConfirmingPresetHiding else { return .send(.delegate(.hidePreset(state.preset))).animation(.default) }
    state.confirmationDialog = Self.hideConfirmationDialogState(displayName: state.preset.displayName)
    return .none.animation(.default)
  }

  private func toggleVisibility(_ state: inout State) -> Effect<Action> {
    var preset = state.preset
    preset.visible.toggle()
    state.preset = preset
    @Dependency(\.defaultDatabase) var database
    try? database.write { try preset.save($0) }
    return .none
  }
}

extension SharedKey where Self == AppStorageKey<Bool>.Default {
  public static var stopConfirmingPresetHiding: Self {
    Self[.appStorage("stopConfirmingPresetHiding"), default: .init()]
  }
}

public struct PresetButtonView: View {
  @Bindable var store: StoreOf<PresetButton>
  @Shared(.activeState) var activeState
  @Environment(\.editMode) private var editMode

  var state: IndicatorModifier.State {
    activeState.activeSoundFontId == store.preset.soundFontId && activeState.activePresetId == store.preset.id ?
      .active : .none
  }

  public var body: some View {
    Button {
      if editMode?.wrappedValue.isEditing == true {
        store.send(.toggleVisibility, animation: .default)
      } else {
        store.send(.buttonTapped, animation: .default)
      }
    } label: {
      Text(store.preset.displayName)
        .font(.buttonFont)
        .indicator(state)
    }
    .listRowSeparatorTint(.accentColor.opacity(0.5))
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
        Image(systemName: "star")
          .tint(.yellow)
      }
    }
    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
      Button {
        store.send(.hideButtonTapped, animation: .default)
      } label: {
        Image(systemName: "eye.slash")
          .tint(.gray)
      }
    }
  }
}

extension PresetButtonView {
  static var preview: some View {
    let _ = prepareDependencies {
      $0.defaultDatabase = try!.appDatabase()
    }

    @Dependency(\.defaultDatabase) var db
    let presets = try! db.read { try! Preset.fetchAll($0) }

    return List {
      PresetButtonView(store: Store(initialState: .init(preset: presets[0])) { PresetButton() })
      PresetButtonView(store: Store(initialState: .init(preset: presets[1])) { PresetButton() })
      PresetButtonView(store: Store(initialState: .init(preset: presets.last!)) { PresetButton() })
    }.listStyle(.plain)
  }
}

#Preview {
  PresetButtonView.preview
}
