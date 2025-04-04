// Copyright © 2025 Brad Howes. All rights reserved.

import ComposableArchitecture
import GRDB
import Models
import SwiftUI

@Reducer
public struct TagsList {

  @Reducer(state: .equatable, .sendable, action: .equatable)
  public enum Destination {
    case edit(TagsEditor)
  }

  @ObservableState
  public struct State: Equatable {
    @Presents var destination: Destination.State?
    var rows: IdentifiedArrayOf<TagButton.State>

    public init(tags: IdentifiedArrayOf<Tag>) {
      self.rows = .init(uniqueElements: tags.map { .init(tag: $0) })
    }
  }

  public enum Action: Equatable {
    case addButtonTapped
    case destination(PresentationAction<Destination.Action>)
    case fetchTags
    case onAppear
    case rows(IdentifiedActionOf<TagButton>)
  }

  public init() {}

  @Dependency(\.defaultDatabase) var database
  @Shared(.activeState) var activeState

  public var body: some ReducerOf<Self> {
    Reduce<State, Action> { state, action in
      switch action {

      case .addButtonTapped: return addTag(&state)
      case .destination(.dismiss): return fetchTags(&state)
      case .destination(.presented(.edit(.addButtonTapped))): return fetchTags(&state)
      case .destination(.presented(.edit(.finalizeDeleteTag))): return fetchTags(&state)
      case .destination: return .none
      case .fetchTags: return fetchTags(&state)
      case .onAppear: return fetchTags(&state)
      case .rows(.element(_, .delegate(.deleteTag(let tag)))): return deleteTag(&state, tag: tag)
      case .rows(.element(_, .delegate(.editTags))): return editTags(&state)
      case .rows: return .none
      }
    }
    .forEach(\.rows, action: \.rows) {
      TagButton()
    }
    .ifLet(\.$destination, action: \.destination)
  }
}

private extension TagsList {

  func addTag(_ state: inout State) -> Effect<Action> {
    @Dependency(\.defaultDatabase) var database
    if let tag = (try? database.write { try Tag.make($0) }) {
      state.rows.append(.init(tag: tag))
    }
    return .none.animation(.default)
  }

  func deleteTag(_ state: inout State, tag: Tag) -> Effect<Action>{
    print("TagsList.deleteTag: \(tag)")
    precondition(!tag.isUbiquitous)
    if activeState.activeTagId == tag.id {
      $activeState.withLock {
        $0.activeTagId = Tag.Ubiquitous.all.id
      }
    }

    _ = try? database.write { try tag.delete($0) }

    return .run { await $0(.fetchTags) }.animation(.default)
  }

  func editTags(_ state: inout State) -> Effect<Action> {
    print("editTags")
    state.destination = .edit(TagsEditor.State(tags: .init(uniqueElements: state.rows.map(\.tag)), focused: nil))
    return .none.animation(.default)
  }

  func fetchTags(_ state: inout State) -> Effect<Action> {
    state.rows = .init(uniqueElements: Tag.ordered.map { .init(tag: $0) })
    return .none.animation(.default)
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
        TagButtonView(store: rowStore)
      }
    }
    .listStyle(.plain)
    .onAppear { _ = store.send(.fetchTags) }
    .sheet(item: $store.scope(state: \.destination?.edit, action: \.destination.edit)) {
      TagsEditorView(store: $0)
    }
  }
}

public struct TagsListNavView: View {
  private var store: StoreOf<TagsList>

  public init(store: StoreOf<TagsList>) {
    self.store = store
  }

  public var body: some View {
    NavigationStack {
      TagsListView(store: store)
        .navigationTitle(Text("Tags"))
    }
  }
}

extension TagsListView {

  static var preview: some View {
    let _ = prepareDependencies { $0.defaultDatabase = try! .appDatabase() }
    @Dependency(\.defaultDatabase) var db
    return TagsListView(store: Store(initialState: .init(tags: Tag.ordered)) { TagsList() })
  }

  static var previewWithEditor: some View {
    let _ = prepareDependencies { $0.defaultDatabase = try! .appDatabase() }
    @Dependency(\.defaultDatabase) var db
    var state = TagsList.State(tags: Tag.ordered)
    state.destination = .edit(TagsEditor.State(tags: .init(uniqueElements: state.rows.map(\.tag)), focused: nil))
    return TagsListView(store: Store(initialState: state) { TagsList() })
  }
}

#Preview {
  TagsListView.preview
}
