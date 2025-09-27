// Copyright © 2025 Brad Howes. All rights reserved.

import ComposableArchitecture
import Dependencies
import SwiftNavigation
import SwiftUI
import Tagged

@Reducer
public struct PresetButton {

  @ObservableState
  public struct State: Equatable, Identifiable {
    public var id: Preset.ID { preset.id }
    var preset: Preset

    public init(preset: Preset) {
      self.preset = preset
    }
  }

  public enum Action: Equatable {
    case buttonTapped
    case delegate(Delegate)
    case deleteFavoriteButtonTapped
    case editButtonTapped
    case favoriteButtonTapped
    case hidePresetButtonTapped
    case longPressGestureFired
    case toggleVisibility

    @CasePathable
    public enum Delegate: Equatable {
      case createFavorite(Preset)
      case deleteFavorite(Preset)
      case editPreset(Preset)
      case hidePreset(Preset)
      case selectPreset(Preset)
    }
  }

  public var body: some ReducerOf<Self> {
    Reduce<State, Action> { state, action in
      switch action {

      case .buttonTapped:
        return .send(.delegate(.selectPreset(state.preset)))

      case .delegate:
        return .none

      case .deleteFavoriteButtonTapped:
        return .send(.delegate(.deleteFavorite(state.preset)))

      case .editButtonTapped:
        return .send(.delegate(.editPreset(state.preset)))

      case .favoriteButtonTapped:
        return .send(.delegate(.createFavorite(state.preset)))

      case .hidePresetButtonTapped:
        return .send(.delegate(.hidePreset(state.preset)))

      case .longPressGestureFired:
        return .send(.delegate(.editPreset(state.preset)))

      case .toggleVisibility:
        state.preset.toggleVisibility()
        return .none
      }
    }
  }

  public init() {}
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
      } else {
        normalButton
          .id(store.preset.id) // !!! For proper scrollTo behavior
          .simultaneousGesture(
            LongPressGesture(minimumDuration: 1.0)
              .onEnded { _ in store.send(.longPressGestureFired) }
          )
      }
    }
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
      store.send(.toggleVisibility, animation: .smooth)
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
