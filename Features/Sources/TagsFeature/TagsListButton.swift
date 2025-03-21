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
public struct TagButton {

  @ObservableState
  public struct State: Equatable, Identifiable {
    public var tag: Tag
    public var id: Tag.ID { tag.id }
    @Presents public var confirmationDialog: ConfirmationDialogState<Action.ConfirmationDialog>?

    public init(tag: Tag) {
      self.tag = tag
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
    case deleteTag(Tag)
    case editTags(Tag)
    case selectTag(Tag)
  }

  public var body: some ReducerOf<Self> {
    Reduce<State, Action> { state, action in
      switch action {

      case .buttonTapped: return .send(.delegate(.selectTag(state.tag)))
      case .confirmationDialog(.presented(.deleteButtonTapped)):
        return .send(.delegate(.deleteTag(state.tag))).animation(.default)
      case .confirmationDialog: return .none
      case .delegate: return .none
      case .deleteButtonTapped: return deleteButtonTapped(&state)
      case .longPressGestureFired: return .send(.delegate(.editTags(state.tag)))
      }
    }
  }
}

extension TagButton {

  static func deleteConfirmationDialogState(displayName: String) -> ConfirmationDialogState<Action.ConfirmationDialog> {
    ConfirmationDialogState {
      TextState("Delete \(displayName) tag?")
    } actions: {
      ButtonState(role: .cancel) { TextState("Cancel") }
      ButtonState(action: .deleteButtonTapped) { TextState("Hide") }
    } message: {
      TextState(
        "Deleting the tag cannot be undone."
      )
    }
  }

  private func deleteButtonTapped(_ state: inout State) -> Effect<Action> {
    state.confirmationDialog = Self.deleteConfirmationDialogState(displayName: state.tag.name)
    return .none.animation(.default)
  }
}

public struct TagButtonView: View {
  @Bindable var store: StoreOf<TagButton>
  @Shared(.activeState) var activeState

  var state: IndicatorModifier.State {
    activeState.activeTagId == store.tag.id ? .active : .none
  }

  public var body: some View {
    Button {
      store.send(.buttonTapped)
    } label: {
      HStack {
        Text(store.tag.name)
        Spacer()
        Text("\(store.tag.soundFontsCount)")
      }
      .font(Font.custom("Eurostile", size: 20))
      .indicator(state)
    }
//    .onCustomLongPressGesture {
//      store.send(.longPressGestureFired, animation: .default)
//    }
    .confirmationDialog($store.scope(state: \.confirmationDialog, action: \.confirmationDialog))
    .swipeActions(edge: .trailing) {
      if store.tag.isUserDefined {
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

private extension DatabaseWriter where Self == DatabaseQueue {
  static var previewDatabase: Self {
    let databaseQueue = try! DatabaseQueue()
    try! databaseQueue.migrate()
    try! databaseQueue.write { db in
      for font in SF2ResourceFileTag.allCases {
        _ = try? SoundFont.make(db, builtin: font)
      }
    }

    let tags = try! databaseQueue.read { try! Tag.fetchAll($0) }
    precondition(tags.count > 0)

    return databaseQueue
  }
}

extension TagButtonView {
  static var preview: some View {
    let _ = prepareDependencies {
      $0.defaultDatabase = .previewDatabase
    }

    @Dependency(\.defaultDatabase) var db
    let tags = try! db.read { try! Tag.fetchAll($0) }

    print(tags.count)

    return List {
      ForEach(tags) { tag in
        TagButtonView(store: Store(initialState: .init(tag: tag)) { TagButton() })
      }
    }
  }
}


#Preview {
  TagButtonView.preview
}
