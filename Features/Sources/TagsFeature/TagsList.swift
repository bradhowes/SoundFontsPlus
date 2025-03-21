// Copyright © 2025 Brad Howes. All rights reserved.

import ComposableArchitecture
import GRDB
import Models
import SF2ResourceFiles
import SwiftUI
import Models

@Reducer
public struct TagsList {

  @Reducer(state: .equatable, .sendable, action: .equatable)
  public enum Destination {
    // case edit(TagsEditor)
  }

  @ObservableState
  public struct State: Equatable {
    @Presents var destination: Destination.State?
    var rows: IdentifiedArrayOf<TagButton.State>

    public init(tags: [Tag]) {
      self.rows = .init(uniqueElements: tags.map { .init(tag: $0) })
    }
  }

  public enum Action {
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

      case .rows(.element(_, .delegate(.deleteTag(let tag)))):
        deleteTag(&state, tag: tag)
        return .none

      case .rows(.element(_, .delegate(.editTags))):
        // state.destination = .edit(TagsEditor.State(tags: state.rows.map(\.tag)))
        return .none

      case .rows(.element(_, .delegate(.selectTag(let tag)))):
        $activeState.withLock {
          $0.activeTagId = tag.id
        }
        return .none

      case .rows:
        return .none
      }
    }
    .forEach(\.rows, action: \.rows) {
      TagButton()
    }
    .ifLet(\.$destination, action: \.destination)
  }
}

extension TagsList {

  private func addTag(_ state: inout State) {
    do {
      try database.write {
        _ = try Tag.make($0, name: "New Tag")
      }
      fetchTags(&state)
    } catch {
      print("failed to create new tag")
    }
  }

  private func deleteTag(_ state: inout State, tag: Tag) {
    precondition(!tag.isUbiquitous)
    if activeState.activeTagId == tag.id {
      $activeState.withLock {
        $0.activeTagId = Tag.Ubiquitous.all.id
      }
    }
    do {
      _ = try database.write { try tag.delete($0) }
      state.rows = state.rows.filter { $0.id != tag.id }
    } catch {
      print("failed to delete tag \(tag.name)")
    }
  }

  private func fetchTags(_ state: inout State) {
    let tags = (try? database.read { try Tag.fetchAll($0) }) ?? []
    state.rows = .init(uniqueElements: tags.map { .init(tag: $0) })
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
    HStack {
      Button("Add Tag", systemImage: "plus") {
        store.send(.addButtonTapped, animation: .default)
      }
    }
    .onAppear { _ = store.send(.fetchTags) }
  }
}

private extension DatabaseWriter where Self == DatabaseQueue {
  static var previewDatabase: Self {
    let databaseQueue = try! DatabaseQueue()
    try! databaseQueue.migrate()
    let tags = try! databaseQueue.read { try! Tag.fetchAll($0) }
    print(tags.count)

    try! databaseQueue.write { db in
      for font in SF2ResourceFileTag.allCases {
        _ = try? SoundFont.make(db, builtin: font)
      }
    }

    @Shared(.activeState) var activeState
    $activeState.withLock {
      $0.activeTagId = tags[0].id
    }

    return databaseQueue
  }
}

extension TagsListView {

  static var preview: some View {
    let _ = prepareDependencies { $0.defaultDatabase = .previewDatabase }
    @Dependency(\.defaultDatabase) var db
    let tags = try! db.read { try! Tag.orderByPrimaryKey().fetchAll($0) }
    return VStack {
      NavigationStack {
        TagsListView(store: Store(initialState: .init(tags: tags)) { TagsList() })
      }
    }
  }
//
//  static var previewEditing: some View {
//    let _ = prepareDependencies { $0.defaultDatabase = .previewDatabase }
//    @Dependency(\.defaultDatabase) var db
//    let soundFonts = try! db.read { try! SoundFont.orderByPrimaryKey().fetchAll($0) }
//
//    return PresetsListView(store: Store(initialState: .init(soundFont: soundFonts[0], editingVisibility: true)) {
//      PresetsList()
//    })
//  }
}

#Preview {
  TagsListView.preview
}
