// Copyright © 2024 Brad Howes. All rights reserved.

import ComposableArchitecture
import SwiftData
import SwiftUI
import Models

@Reducer
public struct TagsListFeature {

  @Reducer(action: .sendable)
  public enum Destination {
    case alert(AlertState<Alert>)
    case edit(TagsEditorFeature)

    @CasePathable
    public enum Alert: Equatable, Sendable {
      case confirmDeletion(tag: UUID)
    }
  }

  @ObservableState
  public struct State: Equatable {
    @Presents var destination: Destination.State?
    var tags: IdentifiedArrayOf<TagModel>
    var activeTag: UUID

    public init(tags: IdentifiedArrayOf<TagModel>, activeTag: UUID) {
      self.tags = tags
      self.activeTag = activeTag
    }
  }

  public enum Action: Sendable {
    case addButtonTapped
    case cancelEditButtonTapped
    case confirmDeletion(tag: UUID)
    case deleteButtonTapped(tag: UUID, name: String)
    case destination(PresentationAction<Destination.Action>)
    case doneEditingButtonTapped
    case fetchTags
    case longPressGestureFired
    case tagButtonTapped(tag: UUID)
  }

  public init() {}

  public var body: some ReducerOf<Self> {
    Reduce<State, Action> { state, action in
      switch action {

      case .addButtonTapped:
        addTag(&state)
        return .none

      case .cancelEditButtonTapped:
        state.destination = nil
        fetchTags(&state)
        return .none

      case .confirmDeletion(let tag):
        deleteTag(&state, tag: tag)
        return .run { _ in
          @Dependency(\.dismiss) var dismiss
          await dismiss()
        }

      case let .deleteButtonTapped(tag, name):
        print("deleteButtonTapped \(tag)")
        state.destination = .alert(.deleteTag(tag, name: name))
        return .none

      case .destination(.presented(.alert(let alertAction))):
        switch alertAction {
        case .confirmDeletion(let tag):
          deleteTag(&state, tag: tag)
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
        state.destination = .edit(TagsEditorFeature.State(tags: state.tags))
        return .none

      case .tagButtonTapped(let tag):
        state.activeTag = tag
        @Shared(.activeTag) var activeTag = tag
        return .none

      @unknown default:
        return .none
      }
    }
    .ifLet(\.$destination, action: \.destination)
  }
}

extension TagsListFeature.Destination.State: Equatable {}

extension TagsListFeature {

  private func addTag(_ state: inout State) {
    do {
      _ = try TagModel.create(name: "New Tag")
      fetchTags(&state)
    } catch {
      print("duplicate tags are not allowed")
    }
  }

  private func fetchTags(_ state: inout State) {
    do {
      state.tags = .init(uniqueElements: try TagModel.tags())
    } catch {
      print("failed to get tags")
    }
  }

  private func deleteTag(_ state: inout State, tag: UUID) {
    do {
      if state.activeTag == tag {
        state.activeTag = TagModel.Ubiquitous.all.uuid
      }
      state.tags = state.tags.filter { $0.uuid != tag }
      try TagModel.delete(tag: tag)
    } catch {
      print("duplicate tags are not allowed")
    }
  }
}

extension AlertState where Action == TagsListFeature.Destination.Alert {
  public static func deleteTag(_ tag: UUID, name: String) -> Self {
    .init {
      TextState("Delete?")
    } actions: {
      ButtonState(role: .destructive, action: .confirmDeletion(tag: tag)) {
        TextState("Yes")
      }
      ButtonState(role: .cancel) {
        TextState("No")
      }
    } message: {
      TextState("Are you sure you want to delete tag \"\(name)\"?")
    }
  }
}

public struct TagsListView: View {
  @Bindable private var store: StoreOf<TagsListFeature>

  public init(store: StoreOf<TagsListFeature>) {
    self.store = store
  }

  public var body: some View {
    List(store.tags, id: \.uuid) { tag in
      TagButtonView(
        name: tag.name,
        tag: tag.uuid,
        isActive: tag.uuid == store.activeTag
      ) {
        store.send(.tagButtonTapped(tag: tag.uuid))
      }
      .onCustomLongPressGesture {
        store.send(.longPressGestureFired)
      }
      .swipeActions(allowsFullSwipe: false) {
        if !tag.ubiquitous {
          Button(role: .destructive) {
            store.send(.deleteButtonTapped(tag: tag.uuid, name: tag.name))
          } label: {
            Label("Delete", systemImage: "trash")
          }
        }
      }
      .alert($store.scope(state: \.destination?.alert, action: \.destination.alert))
    }
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
                store.send(.cancelEditButtonTapped)
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
          activeTag: TagModel.Ubiquitous.all.uuid
      )) {
        TagsListFeature()
      }
    )
  }
}

#Preview {
  TagsListView.preview
}

