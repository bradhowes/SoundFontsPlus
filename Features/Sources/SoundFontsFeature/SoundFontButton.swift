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
public struct SoundFontButton {

  @ObservableState
  public struct State: Equatable, Identifiable {
    public let soundFont: SoundFont
    public var id: SoundFont.ID { soundFont.id }
    @Presents public var confirmationDialog: ConfirmationDialogState<Action.ConfirmationDialog>?

    public init(soundFont: SoundFont) {
      self.soundFont = soundFont
    }
  }

  public enum Action: Equatable {
    case buttonTapped
    case confirmationDialog(PresentationAction<ConfirmationDialog>)
    case delegate(Delegate)
    case deleteButtonTapped
    case editButtonTapped

    @CasePathable
    public enum ConfirmationDialog {
      case cancelButtonTapped
      case deleteButtonTapped
    }
  }

  @CasePathable
  public enum Delegate: Equatable {
    case deleteSoundFont(SoundFont)
    case editSoundFont(SoundFont)
    case selectSoundFont(SoundFont)
  }

  public var body: some ReducerOf<Self> {
    Reduce<State, Action> { state, action in
      switch action {
      case .buttonTapped: return .send(.delegate(.selectSoundFont(state.soundFont)))
      case .confirmationDialog(.presented(.deleteButtonTapped)):
        return .send(.delegate(.deleteSoundFont(state.soundFont))).animation(.default)
      case .confirmationDialog: return .none
      case .delegate: return .none
      case .deleteButtonTapped: return deleteButtonTapped(&state)
      case .editButtonTapped: return .send(.delegate(.editSoundFont(state.soundFont)))
      }
    }
    .ifLet(\.$confirmationDialog, action: \.confirmationDialog)
  }

  public init() {}
}

extension SoundFontButton {

  static func deleteConfirmationDialogState(displayName: String) -> ConfirmationDialogState<Action.ConfirmationDialog> {
    ConfirmationDialogState {
      TextState("Delete \(displayName)?")
    } actions: {
      ButtonState(role: .cancel) { TextState("Cancel") }
      ButtonState(action: .deleteButtonTapped) { TextState("Delete") }
    } message: {
      TextState(
        "Delete \(displayName)?\n\n" +
        "Deleting a sound font will remove it from the application."
      )
    }
  }

  func deleteButtonTapped(_ state: inout State) -> Effect<Action> {
    state.confirmationDialog = Self.deleteConfirmationDialogState(displayName: state.soundFont.displayName)
    return .none.animation(.default)
  }
}

struct SoundFontButtonView: View {
  @Bindable var store: StoreOf<SoundFontButton>
  @Shared(.activeState) var activeState

  var state: IndicatorModifier.State {
    activeState.activeSoundFontId == store.state.soundFont.id ? .active :
    activeState.selectedSoundFontId == store.state.soundFont.id ? .selected : .none
  }

  public var body: some View {
    Button {
      store.send(.buttonTapped, animation: .default)
    } label: {
      Text(store.soundFont.displayName)
        .font(.buttonFont)
        .indicator(state)
    }
    .confirmationDialog($store.scope(state: \.confirmationDialog, action: \.confirmationDialog))
    .swipeActions(edge: .leading, allowsFullSwipe: false) {
      Button {
        store.send(.editButtonTapped, animation: .default)
      } label: {
        Image(systemName: "pencil")
          .tint(.cyan)
      }
    }
    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
      Button {
        store.send(.deleteButtonTapped, animation: .default)
      } label: {
        Image(systemName: "trash")
          .tint(.red)
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
        _ = try? SoundFont.make(db, builtin: font)
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

extension SoundFontButtonView {
  static var preview: some View {
    let _ = prepareDependencies {
      $0.defaultDatabase = .previewDatabase
    }

    @Dependency(\.defaultDatabase) var db
    let soundFonts = try! db.read { try! SoundFont.fetchAll($0) }

    return List {
      SoundFontButtonView(store: Store(initialState: .init(soundFont: soundFonts[0])) { SoundFontButton() })
      SoundFontButtonView(store: Store(initialState: .init(soundFont: soundFonts[1])) { SoundFontButton() })
      SoundFontButtonView(store: Store(initialState: .init(soundFont: soundFonts[2])) { SoundFontButton() })
    }
  }
}

#Preview {
  SoundFontButtonView.preview
}
