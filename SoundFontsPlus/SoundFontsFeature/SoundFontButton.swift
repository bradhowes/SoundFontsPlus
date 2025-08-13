// Copyright © 2025 Brad Howes. All rights reserved.

import ComposableArchitecture
import SharingGRDB
import OSLog
import SwiftNavigation
import SwiftUI
import Tagged

@Reducer
public struct SoundFontButton {
  let logger = Logger(category: "SoundFontButton")

  @ObservableState
  public struct State: Equatable, Identifiable {
    public let soundFontInfo: SoundFontInfo
    public var id: SoundFont.ID { soundFontInfo.id }
    @Presents public var confirmationDialog: ConfirmationDialogState<Action.ConfirmationDialog>?

    public init(soundFontInfo: SoundFontInfo) {
      self.soundFontInfo = soundFontInfo
    }
  }

  public enum Action: Equatable {
    case buttonTapped
    case confirmationDialog(PresentationAction<ConfirmationDialog>)
    case delegate(Delegate)
    case deleteButtonTapped
    case editButtonTapped
    case longPressGestureFired

    @CasePathable
    public enum ConfirmationDialog {
      case cancelButtonTapped
      case deleteButtonTapped
    }
  }

  @CasePathable
  public enum Delegate: Equatable {
    case deleteSoundFont(SoundFontInfo)
    case editSoundFont(SoundFontInfo)
    case selectSoundFont(SoundFontInfo)
  }

  public var body: some ReducerOf<Self> {
    Reduce<State, Action> { state, action in
      switch action {
      case .buttonTapped:
        return .send(.delegate(.selectSoundFont(state.soundFontInfo)))
      case .confirmationDialog(.presented(.deleteButtonTapped)):
        return .send(.delegate(.deleteSoundFont(state.soundFontInfo))).animation(.default)
      case .deleteButtonTapped:
        return deleteButtonTapped(&state)
      case .editButtonTapped:
        return .send(.delegate(.editSoundFont(state.soundFontInfo)))
      case .longPressGestureFired:
        return .send(.delegate(.editSoundFont(state.soundFontInfo)))
      default:
        break
      }
      return .none
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
    if state.soundFontInfo.isInstalled {
      state.confirmationDialog = Self.deleteFromDeviceConfirmationDialogState(displayName: state.soundFontInfo.displayName)
    } else if state.soundFontInfo.isExternal {
      state.confirmationDialog = Self.deleteFromAppConfirmationDialogState(displayName: state.soundFontInfo.displayName)
    } else {
      let name = state.soundFontInfo.displayName
      logger.error("request to delete built-in soundfont \(name)")
    }
    return .none.animation(.default)
  }
}

struct SoundFontButtonView: View {
  @Bindable private var store: StoreOf<SoundFontButton>
  @Shared(.activeState) private var activeState
  private var state: IndicatorModifier.State {
    activeState.activeSoundFontId == store.state.soundFontInfo.id ? .active :
    activeState.selectedSoundFontId == store.state.soundFontInfo.id ? .selected : .none
  }

  public init(store: StoreOf<SoundFontButton>) {
    self.store = store
  }

  public var body: some View {
    Button {
      store.send(.buttonTapped, animation: .default)
    } label: {
      Text(store.soundFontInfo.displayName)
        .font(.button)
        .indicator(state)
    }
    .listRowSeparator(.hidden)
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
      if !store.soundFontInfo.isBuiltIn {
        Button {
          store.send(.deleteButtonTapped, animation: .default)
        } label: {
          Image(systemName: "trash")
            .tint(.red)
        }
      }
    }
    .simultaneousGesture(
      LongPressGesture()
        .onEnded { _ in store.send(.longPressGestureFired) }
    )
  }
}

extension SoundFontButtonView {
  static var preview: some View {
    // swiftlint:disable:next force_try
    let soundFontInfos = try! prepareDependencies {
      // swiftlint:disable:next force_try
      $0.defaultDatabase = try! appDatabase()
      return try $0.defaultDatabase.read { db in
        try Operations.soundFontInfosQuery.fetchAll(db)
      }
    }

    @Shared(.activeState) var activeState
    $activeState.withLock {
      $0.activeSoundFontId = soundFontInfos[0].id
      $0.selectedSoundFontId = soundFontInfos[1].id
    }

    return VStack {
      Section {
        List {
          SoundFontButtonView(store: Store(initialState: .init(soundFontInfo: soundFontInfos[0])) { SoundFontButton() })
          SoundFontButtonView(store: Store(initialState: .init(soundFontInfo: soundFontInfos[1])) { SoundFontButton() })
          SoundFontButtonView(store: Store(initialState: .init(soundFontInfo: soundFontInfos[2])) { SoundFontButton() })
        }
        .listRowSeparator(.hidden)
        .listStyle(.plain)
      }
      List {
        SoundFontButtonView(store: Store(initialState: .init(soundFontInfo: soundFontInfos[0])) { SoundFontButton() })
        SoundFontButtonView(store: Store(initialState: .init(soundFontInfo: soundFontInfos[1])) { SoundFontButton() })
        SoundFontButtonView(store: Store(initialState: .init(soundFontInfo: soundFontInfos[2])) { SoundFontButton() })
      }.listStyle(.grouped)
    }
  }
}

#Preview {
  SoundFontButtonView.preview
}
