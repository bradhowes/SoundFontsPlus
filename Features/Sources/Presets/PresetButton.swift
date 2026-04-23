// Copyright © 2025 Brad Howes. All rights reserved.

import FeatureSupport

/**
 A custom button for a given preset. Tapping the button activates the preset in the synth.
 */
@Reducer
public struct PresetButton {

  @ObservableState
  public struct State: Equatable, Identifiable {
    public var id: Preset.ID { preset.id }
    public var preset: Preset
    public let symbolPrefix: String?

    public init(preset: Preset, symbolPrefix: String?) {
      self.preset = preset
      self.symbolPrefix = symbolPrefix
    }
  }

  public enum Action: Equatable {
    case delegate(Delegate)
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

  public init() {}

  public var body: some ReducerOf<Self> {
    Reduce<State, Action> { state, action in
      switch action {

      case .toggleVisibility:
        state.preset.toggleVisibility()
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
  private var isFavorite: Bool { store.preset.kind == .favorite }
  private var isHidden: Bool { store.preset.kind == .hidden }
  private let indicatorModifierState: IndicatorModifier.State

  public init(store: StoreOf<PresetButton>, indicatorModifierState: IndicatorModifier.State) {
    self.store = store
    self.indicatorModifierState = indicatorModifierState
  }

  public var body: some View {
    Button {
      store.send(editingVisibility ? .toggleVisibility : .delegate(.selectPreset(store.preset)), animation: .default)
    } label: {
      HStack {
        if editingVisibility {
          // Show indicator when edititing preset visibility
          Image(systemName: isHidden ? .circledCheckMarkOffImageName : .circledCheckMarkOnImageName)
            .foregroundStyle(Color.alternateAccentColor)
            .frame(width: 24)
            .animation(.smooth, value: store.preset.kind) // animate the visibiliity toggle image
        }
        if let symbolPrefix = store.symbolPrefix {
          Image(systemName: symbolPrefix)
        }
        Text(store.preset.displayName)
          .font(.button)
        Spacer()
      }
      .indicator(editingVisibility ? .visibilityEditing : indicatorModifierState)
      .contentShape(.interaction, Rectangle())
      .simultaneousGesture(
        LongPressGesture(minimumDuration: 1.0)
          .onEnded { _ in store.send(.delegate(.editPreset(store.preset))) }
      )
    }
    .id(store.preset.id)
    .swipeActions(edge: .leading, allowsFullSwipe: false) {
      if !editingVisibility {
        Button {
          store.send(.delegate(.editPreset(store.preset)), animation: .default)
        } label: {
          Image(systemName: "pencil")
            .tint(.cyan)
        }
        Button {
          store.send(.delegate(.createFavorite(store.preset)), animation: .default)
        } label: {
          Image(systemName: store.preset.isFavorite ? "document.on.document.fill" : "star")
            .tint(Color.alternateAccentColor)
        }
      }
    }
    .animation(.smooth, value: store.preset.displayName)
    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
      if !editingVisibility {
        if store.preset.isFavorite {
          Button {
            store.send(.delegate(.deleteFavorite(store.preset)), animation: .default)
          } label: {
            Image(systemName: "trash")
              .tint(.red)
          }
        } else {
          Button {
            store.send(.delegate(.hidePreset(store.preset)), animation: .default)
          } label: {
            Image(systemName: "eye.slash")
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
      presets.append(presets.last!.clone()!)
      return presets
    }()
    return VStack {
      Text("Normal")
      List {
        PresetButtonView(store: Store(initialState: .init(preset: presets[0], symbolPrefix: nil)) { PresetButton() },
                         indicatorModifierState: .active)
        PresetButtonView(store: Store(initialState: .init(preset: presets[1], symbolPrefix: nil)) { PresetButton() },
                         indicatorModifierState: .favorite)
        // swiftlint:disable:next force_unwrapping
        PresetButtonView(store: Store(initialState: .init(preset: presets.last!, symbolPrefix: "ℹ️")) { PresetButton() },
                         indicatorModifierState: .none)
      }
      .listStyle(.plain)
      .environment(\.editMode, .constant(.inactive))

      Text("Edit Mode")
      List {
        PresetButtonView(store: Store(initialState: .init(preset: presets[0], symbolPrefix: nil)) { PresetButton() },
                         indicatorModifierState: .active)
        PresetButtonView(store: Store(initialState: .init(preset: presets[1], symbolPrefix: nil)) { PresetButton() },
                         indicatorModifierState: .favorite)
        PresetButtonView(store: Store(initialState: .init(preset: presets[2], symbolPrefix: "ℹ️")) { PresetButton() },
                         indicatorModifierState: .none)
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
