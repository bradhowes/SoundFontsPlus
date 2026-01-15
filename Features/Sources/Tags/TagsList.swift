// Copyright © 2025 Brad Howes. All rights reserved.

import FeatureSupport
import SQLiteData

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
    @FetchAll(TagInfo.query, animation: .smooth) public var tagInfos

    public init() {}
  }

  public enum Action {
    case delegate(Delegate)
    case deleteButtonTapped(TagInfo)
    case tagButtonTapped(TagInfo)

    @CasePathable
    public enum Delegate: Equatable {
      case edit(focus: Int?)
    }
  }

  public init() {}

  @Shared(.activeState) private var activeState

  public var body: some ReducerOf<Self> {
    Reduce<State, Action> { state, action in
      switch action {

      case .delegate:
        return .none

      case let .deleteButtonTapped(tagInfo):
        return deleteTag(&state, tagId: tagInfo.id)

      case let .tagButtonTapped(tagInfo):
        return activateTag(&state, tagId: tagInfo.id)
      }
    }
  }
}

extension TagsList {

  private func activateTag(_ state: inout State, tagId: FontTag.ID) -> Effect<Action> {
    $activeState.withLock { $0.activeTagId = tagId }
    return .none
  }

  private func deleteTag(_ state: inout State, tagId: FontTag.ID) -> Effect<Action> {
    if activeState.activeTagId == tagId {
      $activeState.withLock { $0.activeTagId = FontTag.Ubiquitous.all.id }
    }
    try? FontTag.delete(id: tagId)
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
    StyledList {
      Section {
        ForEach(store.tagInfos, id: \.id) { tagInfo in
          StyledEntry {
            button(tagInfo)
          }
        }
      } header: {
        StyledHeader { Text("Tags") }
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
      .font(.button)
      .indicator(activeState.activeTagId == tagInfo.id ? .active : .none )
    }
    .listRowSeparator(.hidden)
    .swipeActions(edge: .leading, allowsFullSwipe: false) {
      Button {
        store.send(.delegate(.edit(focus: tagInfo.ordering)), animation: .smooth)
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
      LongPressGesture(minimumDuration: 1.0)
        .onEnded { _ in store.send(.delegate(.edit(focus: nil))) }
    )
  }
}

#if DEBUG

extension TagsListView {

  static var preview: some View {
    prepareDependencies {
      $0.defaultDatabase = previewDatabase()
      // swiftlint:disable:next force_try
      let tag = try! FontTag.make(displayName: "Another Tag")
      Operations.tagSoundFont(tag.id, soundFontId: 1)
    }

    return TagsListView(store: Store(initialState: .init()) { TagsList() })
  }
}

#Preview {
  TagsListView.preview
}

#endif // DEBUG
