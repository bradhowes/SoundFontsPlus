// Copyright © 2025 Brad Howes. All rights reserved.

import FeatureSupport

/**
 A custom button for a given preset. Tapping the button activates the preset in the synth.
 */
@Reducer
public struct PresetButton {

  @ObservableState
  public struct State: Equatable, Identifiable {
    public let id: Preset.ID
    public var displayName: String
    public let kind: Preset.Kind
    public let symbolPrefix: String?

    public init(id: Preset.ID, displayName: String, kind: Preset.Kind, symbolPrefix: String?) {
      self.id = id
      self.displayName = displayName
      self.kind = kind
      self.symbolPrefix = symbolPrefix
    }
  }

  public enum Action: Equatable {
    case delegate(Delegate)
    case toggleVisibility

    @CasePathable
    public enum Delegate: Equatable {
      case createFavoriteTapped(Preset.ID)
      case deleteFavoriteTapped(Preset.ID)
      case editPresetTapped(Preset.ID)
      case hidePresetTapped(Preset.ID)
      case presetButtonTapped(Preset.ID)
    }
  }

  public init() {}

  public var body: some ReducerOf<Self> {
    Reduce<State, Action> { state, action in
      switch action {

      case .toggleVisibility:
        if var preset = Preset.with(id: state.id) {
          preset.toggleVisibility()
        }
        return .none

      default:
        return .none
      }
    }
  }
}

public struct PresetButtonView: View {
  private var store: StoreOf<PresetButton>
  @Environment(\.editMode) private var editingMode

  private var editingVisibility: Bool { (editingMode?.wrappedValue ?? .inactive) == .active }
  private var isFavorite: Bool { store.kind == .favorite }
  private var isHidden: Bool { store.kind == .hidden }
  private let indicatorModifierState: IndicatorModifier.State

  public init(store: StoreOf<PresetButton>, indicatorModifierState: IndicatorModifier.State) {
    self.store = store
    self.indicatorModifierState = indicatorModifierState
  }

  public var body: some View {
    Button {
      store.send(editingVisibility ? .toggleVisibility : .delegate(.presetButtonTapped(store.id)), animation: .default)
    } label: {
      HStack {
        if editingVisibility {
          // Show indicator when edititing preset visibility
          Image(systemName: isHidden ? .toggleCircleOffImageName : .toggleCircleOnImageName)
            .foregroundStyle(Color.alternateAccentColor)
            .frame(width: 24)
            .animation(.smooth, value: store.kind) // animate the visibiliity toggle image
        }
        if let symbolPrefix = store.symbolPrefix {
          Image(systemName: symbolPrefix)
        }
        Text(store.displayName)
          .font(.button)
        Spacer()
      }
      .indicator(editingVisibility ? .visibilityEditing : indicatorModifierState)
      .contentShape(.interaction, Rectangle())
      .simultaneousGesture(
        LongPressGesture(minimumDuration: 1.0)
          .onEnded { _ in store.send(.delegate(.editPresetTapped(store.id))) }
      )
    }
    .id(store.id)
    .swipeActions(edge: .leading, allowsFullSwipe: false) {
      if !editingVisibility {
        Button {
          store.send(.delegate(.editPresetTapped(store.id)), animation: .default)
        } label: {
          Image(systemName: .editButtonImageName)
            .tint(.cyan)
        }
        Button {
          store.send(.delegate(.createFavoriteTapped(store.id)), animation: .default)
        } label: {
          Image(systemName: isFavorite ? .duplicateFavoriteButtonName : .favoriteButtonImageName)
            .tint(Color.alternateAccentColor)
        }
      }
    }
    .animation(.smooth, value: store.displayName)
    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
      if !editingVisibility {
        if isFavorite {
          Button {
            store.send(.delegate(.deleteFavoriteTapped(store.id)), animation: .default)
          } label: {
            Image(systemName: .deleteButtonImageName)
              .tint(.red)
          }
        } else {
          Button {
            store.send(.delegate(.hidePresetTapped(store.id)), animation: .default)
          } label: {
            Image(systemName: .hidePresetButtonImageName)
              .tint(.purple)
          }
        }
      }
    }
  }
}

#if DEBUG

extension PresetButtonView {
  static var preview: some View {
    let presets: [Preset] = {
      var presets = Preset.all(for: 1)
      // swiftlint:disable:next force_unwrapping
      presets.append(presets.last!.cloneFavorite()!)
      return presets
    }()
    return VStack {
      Text("Normal")
      List {
        PresetButtonView(
          store: Store(
            initialState: .init(
              id: presets[0].id,
              displayName: presets[0].displayName,
              kind: presets[0].kind,
              symbolPrefix: nil
            )
          ) {
            PresetButton()
          },
          indicatorModifierState: .active
        )
        PresetButtonView(
          store: Store(
            initialState: .init(
              id: presets[1].id,
              displayName: presets[1].displayName,
              kind: presets[1].kind,
              symbolPrefix: nil
            )
          ) {
            PresetButton()
          },
          indicatorModifierState: .favorite
        )
        PresetButtonView(
          store: Store(
            initialState: .init(
              // swiftlint:disable:next force_unwrapping
              id: presets.last!.id,
              // swiftlint:disable:next force_unwrapping
              displayName: presets.last!.displayName,
              // swiftlint:disable:next force_unwrapping
              kind: presets.last!.kind,
              symbolPrefix: "ℹ️"
            )
          ) {
            PresetButton()
          },
          indicatorModifierState: .none
        )
      }
      .listStyle(.plain)
      .environment(\.editMode, .constant(.inactive))

      Text("Edit Mode")
      List {
        PresetButtonView(
          store: Store(
            initialState: .init(
              id: presets[0].id,
              displayName: presets[0].displayName,
              kind: presets[0].kind,
              symbolPrefix: nil
            )
          ) {
            PresetButton()
          },
          indicatorModifierState: .active
        )
        PresetButtonView(
          store: Store(
            initialState: .init(
              id: presets[1].id,
              displayName: presets[1].displayName,
              kind: presets[1].kind,
              symbolPrefix: nil
            )
          ) {
            PresetButton()
          },
          indicatorModifierState: .favorite
        )
        PresetButtonView(
          store: Store(
            initialState: .init(
              id: presets[2].id,
              displayName: presets[2].displayName,
              kind: presets[2].kind,
              symbolPrefix: "ℹ️"
            )
          ) {
            PresetButton()
          },
          indicatorModifierState: .none
        )
      }
      .listStyle(.plain)
      .environment(\.editMode, .constant(.active))
    }
  }
}

#Preview {
  // swiftlint:disable:next redundant_discardable_let
  let _ = prepareDependencies {
    $0.defaultDatabase = previewDatabase()
  }
  PresetButtonView.preview
}

#endif // DEBUG
