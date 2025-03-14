// Copyright © 2025 Brad Howes. All rights reserved.

import ComposableArchitecture
import Dependencies
import SharingGRDB
import Models
import SF2ResourceFiles
import SwiftUI
import SwiftUISupport
import Tagged

@Reducer
public struct PresetButton {

  @ObservableState
  public struct State: Identifiable {
    public var preset: Preset
    public var id: Preset.ID { preset.id }
    @Shared(.activeState) var activeState

    public init(preset: Preset) {
      self.preset = preset
    }
  }

  public enum Action {
    case buttonTapped
    case confirmedHiding
    case delegate(Delegate)
    case editButtonTapped
    case favoriteButtonTapped
    case hideButtonTapped
    case longPressGestureFired
  }

  @CasePathable
  public enum Delegate {
    case createFavorite(Preset)
    case editPreset(Preset)
    case hidePreset(Preset)
    case selectPreset(Preset)
  }

  public var body: some ReducerOf<Self> {
    Reduce<State, Action> { state, action in
      switch action {
      case .buttonTapped: return .send(.delegate(.selectPreset(state.preset)))
      case .confirmedHiding: return .send(.delegate(.hidePreset(state.preset)))
      case .delegate: return .none
      case .editButtonTapped: return .send(.delegate(.editPreset(state.preset)))
      case .favoriteButtonTapped: return .send(.delegate(.createFavorite(state.preset)))
      case .hideButtonTapped: return .none
      case .longPressGestureFired: return .send(.delegate(.editPreset(state.preset)))
      }
    }
  }

  public init() {}
}

struct PresetButtonView: View {
  private var store: StoreOf<PresetButton>
  @State var confirmingHiding: Bool = false

  var displayName: String { store.preset.displayName }
  var soundFontId: SoundFont.ID? { store.preset.soundFontId }
  var presetId: Preset.ID { store.preset.id }
  var state: IndicatorModifier.State {
    if store.activeState.activeSoundFontId == soundFontId && store.activeState.activePresetId == presetId {
      return .active
    }
    return .none
  }

  init(store: StoreOf<PresetButton>) {
    self.store = store
  }

  public var body: some View {
    Button {
      store.send(.buttonTapped, animation: .default)
    } label: {
      Text(displayName)
        .font(.buttonFont)
        .indicator(state)
    }
    .onCustomLongPressGesture {
      store.send(.longPressGestureFired, animation: .default)
    }
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
        confirmingHiding = true
      } label: {
        Image(systemName: "eye.slash")
          .tint(.gray)
      }
    }
    .confirmationDialog(
      "Are you sure you want to hide \"\(store.preset.displayName)\" preset?\n\n" +
      "Once hidden It will no longer be visible here but you can restore visibility using the edit visibility control.",
      isPresented: $confirmingHiding,
      titleVisibility: .visible
    ) {
      Button("Confirm", role: .destructive) {
        store.send(.confirmedHiding, animation: .default)
      }
      Button("Cancel", role: .cancel) {
        confirmingHiding = false
      }
    }
  }
}

extension DatabaseWriter where Self == DatabaseQueue {
  static var previewDatabase: Self {
    let databaseQueue = try! DatabaseQueue()
    try! databaseQueue.migrate()
    try! databaseQueue.write { db in
      _ = try! SoundFont.make(db, builtin: .freeFont)
      // _ = try! SoundFont.mock(db, name: "Mock", presetNames: ["Preset 1", "Preset 2", "Preset 3"], tags: [])
    }
    return databaseQueue
  }
}

#Preview {
  let _ = prepareDependencies {
    $0.defaultDatabase = .previewDatabase
  }
  @Dependency(\.defaultDatabase) var db
  let presets = try! db.read { try! Preset.fetchAll($0) }
  List {
    PresetButtonView(store: Store(initialState: .init(preset: presets[0])) { PresetButton() })
//    PresetButtonView(store: Store(initialState: .init(preset: presets[1])) { PresetButton() })
//    PresetButtonView(store: Store(initialState: .init(preset: presets[2])) { PresetButton() })
  }
}
