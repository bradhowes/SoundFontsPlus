// Copyright © 2025 Brad Howes. All rights reserved.

import ComposableArchitecture
import SharingGRDB
import SwiftUI

/**
 Feature that shows a list of tag buttons.

 - Touching a button makes the associated tag active
 - Swiping left offers a button to edit the tags and a button to delete the swiped tag
 - Long-press on a tag to edit the tags
 */
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
    case destination(PresentationAction<Destination.Action>)
    case longPressGestureFired
    case tagButtonTapped(TagInfo)
    case tagSwipedToDelete(TagInfo)
    case tagSwipedToEdit(TagInfo)
  }

  public init() {}

  @Shared(.activeState) var activeState

  public var body: some ReducerOf<Self> {
    Reduce<State, Action> { state, action in
      switch action {
      case .destination: return .none
      case .longPressGestureFired: return editTags(&state, focused: nil)
      case let .tagButtonTapped(tagInfo): return activateTag(&state, tagId: tagInfo.id)
      case let .tagSwipedToDelete(tagInfo): return deleteTag(&state, tagId: tagInfo.id)
      case let .tagSwipedToEdit(tagInfo): return editTags(&state, focused: tagInfo)
      }
    }
    .ifLet(\.$destination, action: \.destination)
  }
}

private extension TagsList {

  func activateTag(_ state: inout State, tagId: Tag.ID) -> Effect<Action> {
    $activeState.withLock {
      $0.activeTagId = tagId
    }
    return .none
  }

  func deleteTag(_ state: inout State, tagId: Tag.ID) -> Effect<Action> {
    if activeState.activeTagId == tagId {
      $activeState.withLock {
        $0.activeTagId = Tag.Ubiquitous.all.id
      }
    }
    Operations.deleteTag(tagId)
    return .none
  }

  func editTags(_ state: inout State, focused: TagInfo? = nil) -> Effect<Action> {
    state.destination = .edit(TagsEditor.State(focused: focused?.id))
    return .none
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
          store.send(.tagSwipedToDelete(tagInfo), animation: .smooth)
        } label: {
          Image(systemName: "trash")
            .tint(.red)
        }
      }
      Button {
        store.send(.tagSwipedToEdit(tagInfo), animation: .smooth)
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
      let tag = try! Tag.make(displayName: "Another Tag")
      Operations.tagSoundFont(tag.id, soundFontId: .init(rawValue: 1))
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
