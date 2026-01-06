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
    public var editingVisibility: Bool

    public init(preset: Preset, editingVisibility: Bool) {
      self.preset = preset
      self.editingVisibility = editingVisibility
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
  @Bindable private var store: StoreOf<PresetButton>
  @Shared(.activeState) var activeState
  private var isFavorite: Bool { store.preset.kind == .favorite }
  private var isHidden: Bool { store.preset.kind == .hidden }

#if os(iOS)
  @Environment(\.editMode) private var editMode
  private var isEditing: Bool { editMode?.wrappedValue == .active }
#endif

#if os(macOS)
  private var isEditing: Bool { false }
#endif

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
      store.send(isEditing ? .toggleVisibility : .delegate(.selectPreset(store.preset)), animation: .default)
    } label: {
      HStack {
        // Show indicator when edititing preset visibility
        Image(systemName: isHidden ? "circle" : "inset.filled.circle")
          .foregroundStyle(Color.orange)
          .frame(width: isEditing ? 24 : 0)
          .opacity(isEditing ? 1.0 : 0.0)
          .disabled(!isEditing)
          .animation(.smooth, value: store.preset.kind) // animate the visibiliity toggle image
          .animation(.smooth, value: isEditing) // animate the transition to/from visibility editing
        PresetNameView(preset: store.preset)
          .indicator(isEditing ? .favorite : state)
      }
    }
    .id(store.preset.id) // !!! For proper scrollTo behavior
    .simultaneousGesture(
      LongPressGesture(minimumDuration: 1.0)
        .onEnded { _ in store.send(.delegate(.editPreset(store.preset))) }
    )
    .listRowSeparator(.hidden)
    .swipeActions(edge: .leading, allowsFullSwipe: false) {
      if !isEditing {
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
      if !isEditing {
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
        PresetButtonView(store: Store(initialState: .init(preset: presets[0], editingVisibility: false)) { PresetButton() })
        PresetButtonView(store: Store(initialState: .init(preset: presets[1], editingVisibility: false)) { PresetButton() })
        // swiftlint:disable:next force_unwrapping
        PresetButtonView(store: Store(initialState: .init(preset: presets.last!, editingVisibility: false)) { PresetButton() })
      }
      .listStyle(.plain)

      Text("Edit Mode")
      List {
        PresetButtonView(store: Store(initialState: .init(preset: presets[0], editingVisibility: true)) { PresetButton() })
        PresetButtonView(store: Store(initialState: .init(preset: presets[1], editingVisibility: true)) { PresetButton() })
        PresetButtonView(store: Store(initialState: .init(preset: presets[2], editingVisibility: true)) { PresetButton() })
      }
      .listStyle(.plain)
    }
  }
}

#Preview {
  PresetButtonView.preview
}
