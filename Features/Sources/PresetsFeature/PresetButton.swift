// Copyright © 2025 Brad Howes. All rights reserved.

import ComposableArchitecture
import GRDB
import Models
import SF2ResourceFiles
import SwiftUI
import SwiftUISupport
import Tagged

@Reducer
public struct PresetButton {

  @ObservableState
  public struct State: Equatable, Identifiable {
    public var id: Preset.ID { presetId }
    public let presetId: Preset.ID
    public let soundFontId: SoundFont.ID
    public let displayName: String
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
    case createFavorite(Preset.ID)
    case editPreset(Preset.ID)
    case hidePreset(Preset.ID)
    case selectPreset(Preset.ID, SoundFont.ID)
  }

  public var body: some ReducerOf<Self> {
    Reduce<State, Action> { state, action in
      switch action {
      case .buttonTapped: return .send(.delegate(.selectPreset(state.presetId, state.soundFontId)))
      case .confirmedHiding: return .send(.delegate(.hidePreset(state.presetId)))
      case .delegate: return .none
      case .editButtonTapped: return .send(.delegate(.editPreset(state.presetId)))
      case .favoriteButtonTapped: return .send(.delegate(.createFavorite(state.presetId)))
      case .hideButtonTapped: return .none
      case .longPressGestureFired: return .send(.delegate(.editPreset(state.presetId)))
      }
    }
  }

  public init() {}
}

public struct PresetButtonView: View {
  let store: StoreOf<PresetButton>
  @State var confirmingHiding: Bool = false
  @Shared(.activeState) var activeState

  var state: IndicatorModifier.State {
    activeState.activeSoundFontId == store.soundFontId && activeState.activePresetId == store.presetId ?
      .active : .none
  }

  public var body: some View {
    Button {
      store.send(.buttonTapped, animation: .default)
    } label: {
      Text(store.displayName)
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
      "Are you sure you want to hide \"\(store.displayName)\" preset?\n\n" +
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
      _ = try! SoundFont.make(db, builtin: .rolandNicePiano)
    }

    let presets = try! databaseQueue.read { try! Preset.fetchAll($0) }

    @Shared(.activeState) var activeState
    $activeState.withLock {
      $0.activePresetId = presets[0].id
      $0.activeSoundFontId = presets[0].soundFontId
      $0.selectedSoundFontId = presets.last!.soundFontId
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
    PresetButtonView(store: Store(initialState: .init(
      presetId: presets[0].id,
      soundFontId: presets[0].soundFontId,
      displayName: presets[0].displayName
    )) { PresetButton() })
    PresetButtonView(store: Store(initialState: .init(
      presetId: presets[1].id,
      soundFontId: presets[1].soundFontId,
      displayName: presets[1].displayName
    )) { PresetButton() })
    PresetButtonView(store: Store(initialState: .init(
      presetId: presets.last!.id,
      soundFontId: presets.last!.soundFontId,
      displayName: presets.last!.displayName
    )) { PresetButton() })
  }
}
