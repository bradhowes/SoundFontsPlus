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
    public var id: Preset.ID { preset.id }
    public let preset: Preset
    public var presetId: Preset.ID { preset.id }
    public var soundFontId: SoundFont.ID { preset.soundFontId }
    public var displayName: String { preset.displayName }
    public var isVisible: Bool

    public init(preset: Preset) {
      self.preset = preset
      self.isVisible = preset.visible
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
    case toggleVisibility
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
      case .toggleVisibility:
        state.isVisible.toggle()
        var preset = state.preset
        preset.visible.toggle()
        @Dependency(\.defaultDatabase) var database
        do {
          try database.write { try preset.save($0) }
        } catch {
          print("failed to save preset change to isVisible: \(error)")
        }
        return .none
      }
    }
  }

  public init() {}
}

extension SharedKey where Self == AppStorageKey<Bool>.Default {
  public static var stopConfirmingPresetHiding: Self {
    Self[.appStorage("stopConfirmingPresetHiding"), default: .init()]
  }
}

public struct PresetButtonView: View {
  let store: StoreOf<PresetButton>
  @State var confirmingHiding: Bool = false
  @Shared(.activeState) var activeState
  @Shared(.stopConfirmingPresetHiding) var stopConfirmingPresetHiding
  @Environment(\.editMode) private var editMode

  var state: IndicatorModifier.State {
    activeState.activeSoundFontId == store.soundFontId && activeState.activePresetId == store.presetId ?
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
      Text(store.displayName)
        .font(.buttonFont)
        .indicator(state)
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
        if !stopConfirmingPresetHiding {
          confirmingHiding = true
        } else {
          store.send(.confirmedHiding, animation: .default)
        }
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
        // $stopConfirmingPresetHiding.withLock { $0 = true }
      }
      Button("Cancel", role: .cancel) {
        confirmingHiding = false
      }
    }
  }
}

private extension DatabaseWriter where Self == DatabaseQueue {
  static var previewDatabase: Self {
    let databaseQueue = try! DatabaseQueue()
    try! databaseQueue.migrate()
    try! databaseQueue.write { db in
      for font in SF2ResourceFileTag.allCases {
        _ = try! SoundFont.make(db, builtin: font)
      }
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
    PresetButtonView(store: Store(initialState: .init(preset: presets[0])) { PresetButton() })
    PresetButtonView(store: Store(initialState: .init(preset: presets[1])) { PresetButton() })
    PresetButtonView(store: Store(initialState: .init(preset: presets.last!)) { PresetButton() })
  }
}
