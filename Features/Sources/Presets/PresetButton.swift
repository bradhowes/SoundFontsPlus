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
  @Shared(.activeState) private var activeState
  @Environment(\.editMode) private var editingMode

  private var editingVisibility: Bool { (editingMode?.wrappedValue ?? .inactive) == .active }
  private var isFavorite: Bool { store.preset.kind == .favorite }
  private var isHidden: Bool { store.preset.kind == .hidden }

  public init(store: StoreOf<PresetButton>) {
    self.store = store
  }

  var state: IndicatorModifier.State {
    if activeState.activeSoundFontId == store.preset.soundFontId,
       activeState.activePresetId == store.preset.id {
      return isFavorite ? .activeFavorite : .active
    }
    return isFavorite ? .favorite : .none
  }

  public var body: some View {
    Button {
      store.send(editingVisibility ? .toggleVisibility : .delegate(.selectPreset(store.preset)), animation: .default)
    } label: {
      HStack {
        if editingVisibility {
          // Show indicator when edititing preset visibility
          Image(systemName: isHidden ? "circle" : "inset.filled.circle")
            .foregroundStyle(Color.orange)
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
      .indicator(editingVisibility ? .favorite : state)
      .contentShape(.interaction, Rectangle())
      .simultaneousGesture(
        LongPressGesture(minimumDuration: 1.0)
          .onEnded { _ in store.send(.delegate(.editPreset(store.preset))) }
      )
    }
    .id(store.preset.id) // !!! For proper scrollTo behavior
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
            .tint(.orange)
        }
      }
    }
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
    var presets = prepareDependencies {
      $0.defaultDatabase = previewDatabase()
      return Operations.presets(for: nil)
    }

    // swiftlint:disable:next force_unwrapping
    if let clone = presets.last!.clone() {
      presets.append(clone)
    }

    return VStack {
      Text("Normal")
      List {
        PresetButtonView(store: Store(initialState: .init(preset: presets[0], symbolPrefix: nil)) { PresetButton() })
        PresetButtonView(store: Store(initialState: .init(preset: presets[1], symbolPrefix: nil)) { PresetButton() })
        // swiftlint:disable:next force_unwrapping
        PresetButtonView(store: Store(initialState: .init(preset: presets.last!, symbolPrefix: "ℹ️")) { PresetButton() })
      }
      .listStyle(.plain)
      .environment(\.editMode, .constant(.inactive))

      Text("Edit Mode")
      List {
        PresetButtonView(store: Store(initialState: .init(preset: presets[0], symbolPrefix: nil)) { PresetButton() })
        PresetButtonView(store: Store(initialState: .init(preset: presets[1], symbolPrefix: nil)) { PresetButton() })
        PresetButtonView(store: Store(initialState: .init(preset: presets[2], symbolPrefix: "ℹ️")) { PresetButton() })
      }
      .listStyle(.plain)
      .environment(\.editMode, .constant(.active))
    }
  }
}

#Preview {
  PresetButtonView.preview
}

#endif // DEBUG
