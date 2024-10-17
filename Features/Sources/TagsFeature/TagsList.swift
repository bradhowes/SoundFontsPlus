// Copyright © 2024 Brad Howes. All rights reserved.

import ComposableArchitecture
import SwiftData
import SwiftUI
import Models

@Reducer
public struct TagsList {

  @Reducer(action: .sendable)
  public enum Destination {
    case alert(AlertState<Support.Alert>)
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

  public enum Action: BindableAction, Sendable {
    case addButtonTapped
    case binding(BindingAction<State>)
    case dismissButtonTapped
    case confirmedDeletion(key: TagModel.Key)
    case deleteButtonTapped(key: TagModel.Key, name: String)
    case destination(PresentationAction<Destination.Action>)
    case doneEditingButtonTapped
    case fetchTags
    case longPressGestureFired
    case tagButtonTapped(key: TagModel.Key)
  }

  public init() {}

  public var body: some ReducerOf<Self> {
    BindingReducer()
    Reduce<State, Action> { state, action in
      switch action {

      case .addButtonTapped:
        addTag(&state)
        return .none

      case .binding:
        return .none

      case .dismissButtonTapped:
        state.destination = nil
        fetchTags(&state)
        return .none

      case .confirmedDeletion(let key):
        deleteTag(&state, key: key)
        return .run { _ in
          @Dependency(\.dismiss) var dismiss
          await dismiss()
        }

      case let .deleteButtonTapped(key, name):
        state.destination = .alert(.confirmTagDeletion(key, name: name))
        return .none

      case .destination(.presented(.alert(let alertAction))):
        switch alertAction {
        case .confirmedDeletion(let key):
          deleteTag(&state, key: key)
        }
        return .none

      case .destination:
        return .none
  
      case .doneEditingButtonTapped:
        state.destination = nil
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

      @unknown default:
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
      print("duplicate tags are not allowed")
    }
  }

  private func deleteTag(_ state: inout State, key: TagModel.Key) {
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
      TagButtonView(
        name: tag.name,
        tag: tag.key,
        isActive: tag.key == store.activeTagKey
      ) {
        store.send(.tagButtonTapped(key: tag.key))
      }
      .onCustomLongPressGesture {
        store.send(.longPressGestureFired)
      }
      .swipeActions(allowsFullSwipe: false) {
        if tag.isUserDefined {
          Button(role: .destructive) {
            store.send(.deleteButtonTapped(key: tag.key, name: tag.name))
          } label: {
            Label("Delete", systemImage: "trash")
          }
        }
      }
    }
    .alert($store.scope(state: \.destination?.alert, action: \.destination.alert))
    HStack {
      Button {
        _ = store.send(.addButtonTapped)
      } label: {
        Image(systemName: "plus")
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
          .navigationTitle("Tags")
          .toolbar {
            ToolbarItem(placement: .cancellationAction) {
              Button("Dismiss") {
                store.send(.dismissButtonTapped)
              }
            }
            ToolbarItem(placement: .automatic) {
              Button {
                tagEditStore.send(.addButtonTapped)
              } label: {
                Image(systemName: "plus")
              }
            }
            ToolbarItem(placement: .automatic) {
              EditButton()
            }
          }
      }
    }
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

