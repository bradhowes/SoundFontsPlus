// Copyright © 2025 Brad Howes. All rights reserved.

import ComposableArchitecture
import Models
import SwiftUI
import SwiftUISupport
import Tagged

@Reducer
public struct TagButton {

  @ObservableState
  public struct State: Equatable, Identifiable {
    public let tagInfo: TagInfo
    public var id: Tag.ID { tagInfo.id }

    @Presents public var confirmationDialog: ConfirmationDialogState<Action.ConfirmationDialog>?

    public init(tagInfo: TagInfo) {
      self.tagInfo = tagInfo
    }
  }

  public enum Action: Equatable {
    case buttonTapped
    case confirmationDialog(PresentationAction<ConfirmationDialog>)
    case delegate(Delegate)
    case deleteButtonTapped
    case longPressGestureFired

    @CasePathable
    public enum ConfirmationDialog {
      case cancelButtonTapped
      case deleteButtonTapped
    }
  }

  @CasePathable
  public enum Delegate: Equatable {
    case deleteTag(TagInfo)
    case editTags
  }

  @Shared(.activeState) var activeState

  public var body: some ReducerOf<Self> {
    Reduce<State, Action> { state, action in
      switch action {

      case .buttonTapped: return buttonTapped(&state)
      case .confirmationDialog(.presented(.deleteButtonTapped)): return .send(.delegate(.deleteTag(state.tagInfo)))
      case .confirmationDialog: return .none
      case .delegate: return .none
      case .deleteButtonTapped: return deleteButtonTapped(&state)
      case .longPressGestureFired: return .send(.delegate(.editTags))
      }
    }
    .ifLet(\.$confirmationDialog, action: \.confirmationDialog)
  }
}

extension TagButton {

  static func deleteConfirmationDialogState(displayName: String) -> ConfirmationDialogState<Action.ConfirmationDialog> {
    ConfirmationDialogState(
      titleVisibility: .visible,
      title: {
        TextState("Delete '\(displayName)'?")
      }, actions: {
        ButtonState(role: .cancel) { TextState("Cancel") }
        ButtonState(role: .destructive, action: .deleteButtonTapped) { TextState("Delete") }
      }, message: {
        TextState("SoundFonts associated with the tag will not be deleted.")
      }
    )
  }

  func buttonTapped(_ state: inout State) -> Effect<Action> {
    $activeState.withLock {
      $0.activeTagId = state.id
    }
    return .none.animation(.default)
  }

  func deleteButtonTapped(_ state: inout State) -> Effect<Action> {
    state.confirmationDialog = Self.deleteConfirmationDialogState(displayName: state.tagInfo.name)
    return .none.animation(.default)
  }
}

public struct TagButtonView: View {
  @Bindable var store: StoreOf<TagButton>
  @Shared(.activeState) var activeState

  var state: IndicatorModifier.State {
    activeState.activeTagId == store.id ? .active : .none
  }

  public var body: some View {
    Button {
      store.send(.buttonTapped)
    } label: {
      HStack {
        Text(store.tagInfo.name)
        Spacer()
        Text("\(store.tagInfo.taggedSoundFontCount)")
      }
      .contentShape(Rectangle())
      .font(Font.custom("Eurostile", size: 20))
      .indicator(state)
    }
    .listRowSeparatorTint(.accentColor.opacity(0.5))
    .withLongPressGesture {
      store.send(.longPressGestureFired, animation: .default)
    }
    .confirmationDialog($store.scope(state: \.confirmationDialog, action: \.confirmationDialog))
    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
      if store.tagInfo.id.isUserDefined {
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

extension TagButtonView {
  static var preview: some View {
    let _ = prepareDependencies {
      $0.defaultDatabase = try! .appDatabase()
    }

    let tagInfos = TagInfo.all()
    return List {
      ForEach(tagInfos) { tagInfo in
        TagButtonView(store: Store(initialState: .init(tagInfo: tagInfo)) { TagButton() })
      }
    }.listStyle(.plain)
  }
}

#Preview {
  TagButtonView.preview
}
