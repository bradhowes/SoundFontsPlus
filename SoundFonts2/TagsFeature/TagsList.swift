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
    @FetchAll(Operations.tagInfosQuery, animation: .smooth) var tagInfos

    public init() {}
  }

  public enum Action: Equatable {
    case deleteButtonTapped(TagInfo)
    case destination(PresentationAction<Destination.Action>)
    case editButtonTapped(TagInfo)
    case longPressGestureFired
    case tagButtonTapped(TagInfo)
  }

  public init() {}

  @Shared(.activeState) var activeState

  public var body: some ReducerOf<Self> {
    Reduce<State, Action> { state, action in
      switch action {
      case let .deleteButtonTapped(tagInfo): return deleteButtonTapped(&state, tagInfo: tagInfo)
      case .destination: return .none
      case let .editButtonTapped(tagInfo): return editTags(&state, focused: tagInfo)
      case .longPressGestureFired: return editTags(&state, focused: nil)
      case let .tagButtonTapped(tagInfo): return tagButtonTapped(&state, tagId: tagInfo.id)
      }
    }
    .ifLet(\.$destination, action: \.destination)
  }
}

private extension TagsList {

  func deleteButtonTapped(_ state: inout State, tagInfo: TagInfo) -> Effect<Action> {
    Operations.deleteTag(tagInfo.id)
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
    return .none.animation(.default)
  }

  func tagButtonTapped(_ state: inout State, tagId: Tag.ID) -> Effect<Action> {
    $activeState.withLock {
      $0.activeTagId = tagId
    }
    return .none.animation(.default)
  }

  func editTags(_ state: inout State, focused: TagInfo? = nil) -> Effect<Action> {
    state.destination = .edit(TagsEditor.State(focused: focused?.id))
    return .none.animation(.default)
  }
}

public struct TagsListView: View {
  @Bindable private var store: StoreOf<TagsList>
  @Shared(.activeState) private var activeState

  public init(store: StoreOf<TagsList>) {
    self.store = store
  }

  public var body: some View {
    StyledList(title: "Tags") {
      ForEach(store.tagInfos, id: \.id) { tagInfo in
        button(tagInfo)
      }
    }
    .sheet(item: $store.scope(state: \.destination?.edit, action: \.destination.edit)) {
      TagsEditorView(store: $0)
    }
  }

  private func button(_ tagInfo: TagInfo) -> some View {
    Button {
      store.send(.tagButtonTapped(tagInfo))
    } label: {
      HStack {
        Text(tagInfo.displayName)
        Spacer()
        Text("\(tagInfo.soundFontsCount)")
      }
      .contentShape(Rectangle())
      .font(Font.custom("Eurostile", size: 20))
      .indicator(activeState.activeTagId == tagInfo.id ? .active : .none )
    }
    .listRowSeparatorTint(.accentColor.opacity(0.5))
    .withLongPressGesture {
      store.send(.longPressGestureFired, animation: .default)
    }
    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
      if tagInfo.id.isUserDefined {
        Button {
          store.send(.deleteButtonTapped(tagInfo), animation: .smooth)
        } label: {
          Image(systemName: "trash")
            .tint(.red)
        }
      }
      Button {
        store.send(.editButtonTapped(tagInfo), animation: .smooth)
      } label: {
        Image(systemName: "pencil.circle")
      }
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
