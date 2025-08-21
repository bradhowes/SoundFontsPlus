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

  @ObservableState
  public struct State: Equatable {
    @FetchAll(Operations.tagInfosQuery, animation: .smooth) var tagInfos

    public init() {}
  }

  public enum Action: Equatable {
    case delegate(Delegate)
    case deleteButtonTapped(TagInfo)
    case editButtonTapped(TagInfo)
    case longPressGestureFired
    case tagButtonTapped(TagInfo)
    public enum Delegate: Equatable {
      case edit(TagInfo.ID?)
    }
  }

  public init() {}

  @Shared(.activeState) var activeState

  public var body: some ReducerOf<Self> {
    Reduce<State, Action> { state, action in
      switch action {

      case .delegate:
        return .none

      case let .deleteButtonTapped(tagInfo):
        return deleteTag(&state, tagId: tagInfo.id)

      case let .editButtonTapped(tagInfo):
        return editTags(&state, focused: tagInfo)

      case let .tagButtonTapped(tagInfo):
        return activateTag(&state, tagId: tagInfo.id)

      case .longPressGestureFired:
        return editTags(&state, focused: nil)
      }
    }
  }
}

private extension TagsList {

  func activateTag(_ state: inout State, tagId: FontTag.ID) -> Effect<Action> {
    $activeState.withLock {
      $0.activeTagId = tagId
    }
    return .none
  }

  func deleteTag(_ state: inout State, tagId: FontTag.ID) -> Effect<Action> {
    if activeState.activeTagId == tagId {
      $activeState.withLock {
        $0.activeTagId = FontTag.Ubiquitous.all.id
      }
    }
    Operations.deleteTag(tagId)
    return .none
  }

  func editTags(_ state: inout State, focused: TagInfo? = nil) -> Effect<Action> {
    return .send(.delegate(.edit(focused?.id)))
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
    .listRowSeparator(.hidden)
    .swipeActions(edge: .leading, allowsFullSwipe: false) {
      Button {
        store.send(.editButtonTapped(tagInfo), animation: .smooth)
      } label: {
        Image(systemName: "pencil")
          .tint(.cyan)
      }
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
    }
    .simultaneousGesture(
      LongPressGesture()
        .onEnded { _ in store.send(.longPressGestureFired) }
    )
  }
}

extension TagsListView {

  static var preview: some View {
    prepareDependencies {
      // swiftlint:disable:next force_try
      $0.defaultDatabase = try! appDatabase()
      // swiftlint:disable:next force_try
      let tag = try! FontTag.make(displayName: "Another Tag")
      Operations.tagSoundFont(tag.id, soundFontId: .init(rawValue: 1))
    }

    return TagsListView(store: Store(initialState: .init()) { TagsList() })
  }
}

#Preview {
  TagsListView.preview
}
