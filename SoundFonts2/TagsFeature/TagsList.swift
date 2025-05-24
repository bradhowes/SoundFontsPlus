// Copyright © 2025 Brad Howes. All rights reserved.

import ComposableArchitecture
import SharingGRDB
import SwiftUI

@Reducer
public struct TagsList {

  @Reducer(state: .equatable, .sendable, action: .equatable)
  public enum Destination: Sendable {
    case edit(TagsEditor)
  }

  @ObservableState
  public struct State: Equatable {
    @Presents var destination: Destination.State?
    var rows: IdentifiedArrayOf<TagButton.State>

    public init() {
      @FetchAll(Operations.tagInfos) var tagInfos
      self.rows = .init(uniqueElements: tagInfos.map { .init(tagInfo: $0) })
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
      case .rows(.element(_, .delegate(.deleteTag(let tagInfo)))): return deleteTag(&state, tagInfo: tagInfo)
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
    if let tag = try? Tag.make(displayName: "New Tag") {
      state.rows.append(.init(tagInfo: TagInfo(id: tag.id, displayName: tag.displayName, soundFontsCount: 0)))
    }
    return .none.animation(.default)
  }

  func deleteTag(_ state: inout State, tagInfo: TagInfo) -> Effect<Action>{
    precondition(tagInfo.id.isUserDefined)
    if activeState.activeTagId == tagInfo.id {
      $activeState.withLock {
        $0.activeTagId = Tag.Ubiquitous.all.id
      }
    }

    try? Tag.delete(id: tagInfo.id)

    return .run { await $0(.fetchTags) }.animation(.default)
  }

  func editTags(_ state: inout State) -> Effect<Action> {
    state.destination = .edit(TagsEditor.State(focused: nil))
    return .none.animation(.default)
  }

  func fetchTags(_ state: inout State) -> Effect<Action> {
    @FetchAll(Operations.tagInfos) var tagInfos
    state.rows = .init(uniqueElements: tagInfos.map{ .init(tagInfo: $0) })
    return .none.animation(.default)
  }
}

public struct TagsListView: View {
  @Bindable private var store: StoreOf<TagsList>

  public init(store: StoreOf<TagsList>) {
    self.store = store
  }

  public var body: some View {
    StyledList(title: "Tags") {
      ForEach(store.scope(state: \.rows, action: \.rows)) { rowStore in
        TagButtonView(store: rowStore)
      }
    }
    .sheet(item: $store.scope(state: \.destination?.edit, action: \.destination.edit)) {
      TagsEditorView(store: $0)
    }
    .onAppear {
      store.send(.onAppear)
    }
  }
}

extension TagsListView {

  static var preview: some View {
    let _ = prepareDependencies {
      $0.defaultDatabase = try! appDatabase()
    }

    return TagsListView(store: Store(initialState: .init()) { TagsList() })
  }

  static var previewWithEditor: some View {
    let _ = prepareDependencies { $0.defaultDatabase = try! appDatabase() }
    var state = TagsList.State()
    state.destination = .edit(TagsEditor.State(focused: nil))
    return TagsListView(store: Store(initialState: state) { TagsList() })
  }
}

#Preview {
  TagsListView.preview
}
