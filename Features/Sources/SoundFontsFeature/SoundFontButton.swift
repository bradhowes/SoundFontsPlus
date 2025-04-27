// Copyright © 2025 Brad Howes. All rights reserved.

import ComposableArchitecture
import Extensions
import GRDB
import Models
import OSLog
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

  static func deleteFromAppConfirmationDialogState(displayName: String) -> ConfirmationDialogState<Action.ConfirmationDialog> {
    ConfirmationDialogState(
      titleVisibility: .visible,
      title: {
        TextState("Delete \(displayName)?")
    }, actions: {
      ButtonState(role: .cancel) { TextState("Cancel") }
      ButtonState(action: .deleteButtonTapped) { TextState("Delete") }
    }, message: {
      TextState(
        "Deleting will remove the sound font from this application. It will remain on " +
        "your device."
      )
    })
  }

  static func deleteFromDeviceConfirmationDialogState(displayName: String) -> ConfirmationDialogState<Action.ConfirmationDialog> {
    ConfirmationDialogState(
      titleVisibility: .visible,
      title: {
        TextState("Delete \(displayName)?")
      }, actions: {
        ButtonState(role: .cancel) { TextState("Cancel") }
        ButtonState(action: .deleteButtonTapped) { TextState("Delete") }
      }, message: {
        TextState(
          "Deleting will remove it from the application and your device."
        )
      })
  }

  func deleteButtonTapped(_ state: inout State) -> Effect<Action> {
    if state.soundFont.isInstalled {
      state.confirmationDialog = Self.deleteFromDeviceConfirmationDialogState(displayName: state.soundFont.displayName)
    } else if state.soundFont.isExternal {
      state.confirmationDialog = Self.deleteFromAppConfirmationDialogState(displayName: state.soundFont.displayName)
    } else {
      let name = state.soundFont.displayName
      Logger.soundFonts.warning("request to delete built-in soundfont \(name)")
    }
    return .none.animation(.default)
  }
}

struct SoundFontButtonView: View {
  @Bindable private var store: StoreOf<SoundFontButton>
  @Shared(.activeState) private var activeState
  private var state: IndicatorModifier.State {
    activeState.activeSoundFontId == store.state.soundFont.id ? .active :
    activeState.selectedSoundFontId == store.state.soundFont.id ? .selected : .none
  }

  public init(store: StoreOf<SoundFontButton>) {
    self.store = store
  }

  public var body: some View {
    Button {
      store.send(.buttonTapped, animation: .default)
    } label: {
      Text(store.soundFont.displayName)
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
    }
    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
      if !store.soundFont.isbuiltin {
        Button {
          store.send(.deleteButtonTapped, animation: .default)
        } label: {
          Image(systemName: "trash")
            .tint(.red)
        }
      }
    }
  }
}

extension SoundFontButtonView {
  static var preview: some View {
    let _ = prepareDependencies {
      $0.defaultDatabase = try!.appDatabase()
    }

    @Dependency(\.defaultDatabase) var db
    let soundFonts = try! db.read { try! SoundFont.fetchAll($0) }

    @Shared(.activeState) var activeState
    $activeState.withLock {
      $0.activeSoundFontId = soundFonts[0].id
      $0.selectedSoundFontId = soundFonts[1].id
    }

    return VStack {
      Section {
        List {
          SoundFontButtonView(store: Store(initialState: .init(soundFont: soundFonts[0])) { SoundFontButton() })
          SoundFontButtonView(store: Store(initialState: .init(soundFont: soundFonts[1])) { SoundFontButton() })
          SoundFontButtonView(store: Store(initialState: .init(soundFont: soundFonts[2])) { SoundFontButton() })
        }
        .listStyle(.plain)
        .listRowSeparator(.visible)
        .listRowSeparatorTint(.green, edges: .all)
      }
      List {
        SoundFontButtonView(store: Store(initialState: .init(soundFont: soundFonts[0])) { SoundFontButton() })
        SoundFontButtonView(store: Store(initialState: .init(soundFont: soundFonts[1])) { SoundFontButton() })
        SoundFontButtonView(store: Store(initialState: .init(soundFont: soundFonts[2])) { SoundFontButton() })
      }.listStyle(.grouped)
    }
  }
}

#Preview {
  SoundFontButtonView.preview
}
