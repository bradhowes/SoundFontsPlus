// Copyright © 2024 Brad Howes. All rights reserved.

import ComposableArchitecture
import SwiftData
import SwiftUI
import SwiftUISupport
import Models

@Reducer
public struct TagsList {

  @Reducer
  public enum Destination {
    case edit(TagsEditor)
  }

  @ObservableState
  public struct State: Equatable {
    @Presents var destination: Destination.State?
    var rows: IdentifiedArrayOf<TagsListButton.State>
    @Shared(.activeState) var activeState = .init()

    public init(tags: [TagModel]) {
      self.rows = .init(uniqueElements: tags.map { .init(tag: $0) })
    }
  }

  public enum Action {
    case addButtonTapped
    case destination(PresentationAction<Destination.Action>)
    case fetchTags
    case onAppear
    case rows(IdentifiedActionOf<TagsListButton>)
    case task
  }

  public init() {}

  public var body: some ReducerOf<Self> {
    Reduce<State, Action> { state, action in
      switch action {

      case .addButtonTapped:
        addTag(&state)
        return .none

      case .destination(.dismiss):
        fetchTags(&state)
        return .none

      case .destination:
        return .none

      case .fetchTags:
        fetchTags(&state)
        return .none

      case .onAppear:
        fetchTags(&state)
        return .none

      case .rows(.element(let key, .delegate(.deleteTag))):
        deleteTag(&state, key: key)
        return .none

      case .rows(.element(_, .delegate(.editTags))):
        state.destination = .edit(TagsEditor.State(tags: state.rows.map(\.tag)))
        return .none

      case .rows(.element(let key, .delegate(.selectTag))):
        state.activeState.setActiveTagKey(key)
        return .none

      case .task:
        @Dependency(\.tagsChanged) var tagsChanged
        return .run { send in
          for await _ in await tagsChanged() {
            await send(.fetchTags)
          }
        }

      case .rows:
        return .none
      }
    }
    .forEach(\.rows, action: \.rows) {
      TagsListButton()
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
      if state.activeState.activeTagKey == key {
        state.activeState.setActiveTagKey(TagModel.Ubiquitous.all.key)
      }
      state.rows = state.rows.filter { $0.key != key }
      try TagModel.delete(key: key)
    } catch {
      print("failed to delete tag \(key)")
    }
  }

  private func fetchTags(_ state: inout State) {
    state.rows = .init(uniqueElements: ((try? TagModel.tags()) ?? []).map { .init(tag: $0) })
  }
}

extension DependencyValues {
  public var tagsChanged: @Sendable () async -> any AsyncSequence<Void, Never> {
    get { self[TagsChangedKey.self] }
    set { self[TagsChangedKey.self] = newValue }
  }
}

private enum TagsChangedKey: DependencyKey {
  static let liveValue: @Sendable () async -> any AsyncSequence<Void, Never> = {
    NotificationCenter.default
      .notifications(named: Notifications.tagsChanged)
      .map { _ in }
  }
}

public struct TagsListView: View {
  @Bindable private var store: StoreOf<TagsList>

  public init(store: StoreOf<TagsList>) {
    self.store = store
  }

  public var body: some View {
    List {
      ForEach(store.scope(state: \.rows, action: \.rows)) { rowStore in
        TagsListButtonView(store: rowStore)
      }
    }
    HStack {
      Button("Add Tag", systemImage: "plus") {
        store.send(.addButtonTapped, animation: .default)
      }
    }
    .task { await store.send(.task).finish() }
    .onAppear { _ = store.send(.fetchTags) }
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
  static var preview: some View {
    let tags = (try? TagModel.tags()) ?? []
    return TagsListView(store: Store(initialState: .init(tags: tags)) { TagsList() })
  }
}

#Preview {
  TagsListView.preview
}

