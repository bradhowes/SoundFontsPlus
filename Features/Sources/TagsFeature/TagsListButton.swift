// Copyright © 2024 Brad Howes. All rights reserved.

import ComposableArchitecture
import SwiftUI
import Models
import Tagged

@Reducer
public struct TagsListButton {

  @ObservableState
  public struct State: Equatable, Identifiable {
    var tag: TagModel
    public var id: TagModel.Key { tag.key }
    @Shared(.activeState) var activeState = ActiveState()

    public init(tag: TagModel) {
      self.tag = tag
    }
  }

  public enum Action: Sendable {
    case buttonTapped
    case confirmedDeletion
    case delegate(Delegate)
    case longPressGestureFired
  }

  @CasePathable
  public enum Delegate: Sendable {
    case deleteTag
    case editTags
    case selectTag
  }

  public var body: some ReducerOf<Self> {
    Reduce<State, Action> { state, action in
      switch action {
      case .buttonTapped: return .send(.delegate(.selectTag))
      case .confirmedDeletion: return .send(.delegate(.deleteTag))
      case .delegate: return .none
      case .longPressGestureFired: return .send(.delegate(.editTags))
      }
    }
  }
}

public struct TagsListButtonView: View {
  private var store: StoreOf<TagsListButton>
  @State var confirmingDeletion: Bool = false

  var isActive: Bool { store.activeState.activeTagKey == store.tag.key }
  var name: String { store.tag.name }
  var key: TagModel.Key { store.tag.key }

  public init(store: StoreOf<TagsListButton>) {
    self.store = store
  }

  public var body: some View {
    Button {
      store.send(.buttonTapped)
    } label: {
      HStack {
        Text(store.tag.name)
        Spacer()
        Text("\(store.tag.tagged.count)")
      }
      .indicator(isActive)
    }
    .onCustomLongPressGesture {
      store.send(.longPressGestureFired, animation: .default)
    }
    .swipeToDeleteTag(
      enabled: store.tag.isUserDefined,
      showingConfirmation: $confirmingDeletion,
      key: key,
      name: name) { store.send(.confirmedDeletion, animation: .default) }
  }
}

#Preview {
  List {
    TagsListButtonView(
      store: .init(
        initialState: .init(
          tag: .init(
            key: .init(.init(0)),
            ordering: 0,
            name: "Ubiquitous Tag",
            ubiquitous: true
          )
        )
      ) { TagsListButton() }
    )
    TagsListButtonView(
      store: .init(
        initialState: .init(
          tag: .init(
            key: .init(.init(1)),
            ordering: 1,
            name: "User Tag",
            ubiquitous: false
          )
        )
      ) { TagsListButton() }
    )
    .onCustomLongPressGesture {
      print("long press")
    }
  }
}
