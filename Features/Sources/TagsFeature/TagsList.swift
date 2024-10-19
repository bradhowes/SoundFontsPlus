// Copyright © 2024 Brad Howes. All rights reserved.

import ComposableArchitecture
import SwiftData
import SwiftUI
import Models

@Reducer
public struct TagsList {

  @Reducer(action: .sendable)
  public enum Destination {
    case edit(TagsEditor)
  }

  @ObservableState
  public struct State: Equatable {
    @Presents var destination: Destination.State?
    var tags: IdentifiedArrayOf<TagModel>
    var activeTagKey: TagModel.Key

    public init(tags: IdentifiedArrayOf<TagModel>, activeTagKey: TagModel.Key) {
      self.tags = tags
      self.activeTagKey = activeTagKey
    }
  }

  public enum Action: Sendable {
    case addButtonTapped
    case confirmedDeletion(key: TagModel.Key)
    case destination(PresentationAction<Destination.Action>)
    case fetchTags
    case longPressGestureFired
    case tagButtonTapped(key: TagModel.Key)
  }

  public init() {}

  public var body: some ReducerOf<Self> {
    Reduce<State, Action> { state, action in
      switch action {

      case .addButtonTapped:
        addTag(&state)
        return .none

      case .confirmedDeletion(let key):
        deleteTag(&state, key: key)
        return .none

      case .destination(.dismiss):
        state.destination = nil
        fetchTags(&state)
        return .none

      case .destination:
        return .none

      case .fetchTags:
        fetchTags(&state)
        return .none

      case .longPressGestureFired:
        state.destination = .edit(TagsEditor.State(tags: state.tags))
        return .none

      case .tagButtonTapped(let key):
        state.activeTagKey = key
        @Shared(.activeTagKey) var activeTagKey = key
        return .none
      }
    }
    .ifLet(\.$destination, action: \.destination)
  }
}

extension TagsList.Destination.State: Equatable {}

extension TagsList {

  private func addTag(_ state: inout State) {
    do {
      _ = try TagModel.create(name: "New Tag")
      fetchTags(&state)
    } catch {
      print("failed to create new tag")
    }
  }

  private func deleteTag(_ state: inout State, key: TagModel.Key) {
    precondition(!TagModel.Ubiquitous.contains(key: key))
    do {
      if state.activeTagKey == key {
        state.activeTagKey = TagModel.Ubiquitous.all.key
      }
      state.tags = state.tags.filter { $0.key != key }
      try TagModel.delete(key: key)
    } catch {
      print("failed to delete tag \(key)")
    }
  }

  private func fetchTags(_ state: inout State) {
    state.tags = .init(uniqueElements: (try? TagModel.tags()) ?? [])
  }
}

public struct TagsListView: View {
  @Bindable private var store: StoreOf<TagsList>

  public init(store: StoreOf<TagsList>) {
    self.store = store
  }

  public var body: some View {
    List(store.tags, id: \.key) { tag in
      tagButton(tag: tag)
    }
    HStack {
      Button("Add Tag", systemImage: "plus") {
        store.send(.addButtonTapped, animation: .default)
      }
    }
    .onAppear() {
      _ = store.send(.fetchTags)
    }
    .sheet(
      item: $store.scope(state: \.destination?.edit, action: \.destination.edit)
    ) { tagEditStore in
      NavigationStack {
        TagsEditorView(store: tagEditStore)
      }
    }
  }
}

extension TagsListView {

  private func tagButton(tag: TagModel) -> some View {
    TagButtonView(
      name: tag.name,
      key: tag.key,
      isActive: tag.key == store.activeTagKey,
      activateAction: { store.send(.tagButtonTapped(key: $0), animation: .default) },
      deleteAction: deleteAction(tag: tag)
    )
    .onCustomLongPressGesture {
      store.send(.longPressGestureFired, animation: .default)
    }
  }

  private func deleteAction(tag: TagModel) -> ((TagModel.Key) -> Void)? {
    tag.isUserDefined ? { store.send(.confirmedDeletion(key: $0), animation: .default) } : nil
  }
}

extension TagsListView {
  static var preview: some View {
    let tags = (try? TagModel.tags()) ?? []
    return TagsListView(
      store: Store(
        initialState: .init(
          tags: .init(uniqueElements: tags),
          activeTagKey: TagModel.Ubiquitous.all.key
      )) {
        TagsList()
      }
    )
  }
}

#Preview {
  TagsListView.preview
}

