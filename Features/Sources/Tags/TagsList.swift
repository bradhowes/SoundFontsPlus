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
    case editButtonTapped(TagInfo)
    case longPressGestureFired
    case tagButtonTapped(TagInfo)

    @CasePathable
    public enum Delegate: Equatable {
      case edit(TagInfo.ID?)
    }
  }

  public init() {}

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

extension TagsList {

  private func activateTag(_ state: inout State, tagId: FontTag.ID) -> Effect<Action> {
    ActiveState.setTagId(tagId)
    return .none
  }

  private func deleteTag(_ state: inout State, tagId: FontTag.ID) -> Effect<Action> {
    if ActiveState.value.activeTagId == tagId {
      ActiveState.setTagId(FontTag.Ubiquitous.all.id)
    }
    try? FontTag.delete(id: tagId)
    return .none
  }

  private func editTags(_ state: inout State, focused: TagInfo? = nil) -> Effect<Action> {
    return .send(.delegate(.edit(focused?.id)))
  }
}

public struct TagsListView: View {
  @Bindable private var store: StoreOf<TagsList>

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
      .indicator(ActiveState.value.activeTagId == tagInfo.id ? .active : .none )
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
      LongPressGesture(minimumDuration: 1.0)
        .onEnded { _ in store.send(.longPressGestureFired) }
    )
  }
}

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
