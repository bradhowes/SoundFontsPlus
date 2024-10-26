// Copyright © 2024 Brad Howes. All rights reserved.

import ComposableArchitecture
import SwiftUI
import SwiftUISupport
import Models
import Tagged

@Reducer
public struct TagsListButton {

  @ObservableState
  public struct State: Equatable, Identifiable {
    public var id: TagModel.Key { key }
    let tag: TagModel
    let name: String
    let key: TagModel.Key
    let count: Int
    let isUserDefined: Bool
    @Shared(.activeState) var activeState

    public init(tag: TagModel) {
      self.tag = tag
      self.name = tag.name
      self.key = tag.key
      self.count = tag.tagged.count
      self.isUserDefined = tag.isUserDefined
    }
  }

  public enum Action {
    case buttonTapped
    case confirmedDeletion
    case delegate(Delegate)
    case longPressGestureFired
  }

  @CasePathable
  public enum Delegate {
    case deleteTag
    case editTags
    case selectTag
  }

  public var body: some ReducerOf<Self> {
    Reduce<State, Action> { state, action in
      switch action {

      case .buttonTapped:
        return .send(.delegate(.selectTag))

      case .confirmedDeletion:
        return .send(.delegate(.deleteTag))

      case .delegate:
        return .none

      case .longPressGestureFired:
        return .send(.delegate(.editTags))
      }
    }
  }
}

public struct TagsListButtonView: View {
  private var store: StoreOf<TagsListButton>
  @State var confirmingDeletion: Bool = false

  var isActive: Bool { store.activeState.activeTagKey == store.key }
  var name: String { store.name }
  var key: TagModel.Key { store.key }
  var count: Int { store.count }
  var isUserDefined: Bool { store.isUserDefined }

  public init(store: StoreOf<TagsListButton>) {
    self.store = store
  }

  public var body: some View {
    Button {
      store.send(.buttonTapped)
    } label: {
      HStack {
        Text(name)
        Spacer()
        Text("\(count)")
      }
      .font(Font.custom("Eurostile", size: 20))
      .indicator(isActive)
    }
    .onCustomLongPressGesture {
      store.send(.longPressGestureFired, animation: .default)
    }
    .swipeActions(edge: .trailing) {
      if isUserDefined {
        Button {
          confirmingDeletion = true
        } label: {
          Image(systemName: "trash")
            .tint(.red)
        }
      }
    }
    .confirmationDialog(
      "Are you sure you want to delete \(name)?",
      isPresented: $confirmingDeletion,
      titleVisibility: .visible
    ) {
      Button("Confirm", role: .destructive) {
        store.send(.confirmedDeletion, animation: .default)
      }
      Button("Cancel", role: .cancel) {
        confirmingDeletion = false
      }
    }
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
