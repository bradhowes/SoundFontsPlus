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
    @FetchAll public var tagInfos: [TagInfo]

    public init() {}
  }

  public enum Action {
    case delegate(Delegate)
    case deleteButtonTapped(TagInfo)
    case initialize
    case tagButtonTapped(TagInfo)
    case updateFetchAllQuery

    @CasePathable
    public enum Delegate: Equatable {
      case edit(focus: Int?)
    }
  }

  public init() {}

  @Shared(.activeState) private var activeState
  @Shared(.hideEmptyTags) public var hideEmptyTags

  public var body: some ReducerOf<Self> {

    Reduce<State, Action> { state, action in

      log.action("TagsList", action)

      switch action {

      case .delegate:
        return .none

      case let .deleteButtonTapped(tagInfo):
        return deleteTag(&state, tagId: tagInfo.id)

      case .initialize:
        return initialize(&state)

      case let .tagButtonTapped(tagInfo):
        return activateTag(&state, tagId: tagInfo.id)

      case .updateFetchAllQuery:
        return updateFetchAllQuery(&state)

      }
    }
  }

  private enum CancelId {
    case tagsListUpdateFetchAllQuery
  }
}

extension TagsList {

  private func activateTag(_ state: inout State, tagId: Tag.ID) -> Effect<Action> {
    $activeState.withLock { $0.activeTagId = tagId }
    return .none
  }

  private func deleteTag(_ state: inout State, tagId: Tag.ID) -> Effect<Action> {
    if activeState.activeTagId == tagId {
      $activeState.withLock { $0.activeTagId = Tag.Ubiquitous.all.id }
    }
    try? Tag.delete(id: tagId)
    return .none
  }

  private func initialize(_ state: inout State) -> Effect<Action> {
    .merge(
      monitorHideEmptyTags(&state),
      updateFetchAllQuery(&state)
    )
  }

  private func monitorHideEmptyTags(_ state: inout State) -> Effect<Action> {
    .publisher {
      $hideEmptyTags
        .publisher
        .removeDuplicates()
        .map { _ in
          print("*** monitorHideEmptyTags")
          return .updateFetchAllQuery
        }
    }
  }

  private func updateFetchAllQuery(_ state: inout State) -> Effect<Action> {
    print("*** updateFetchAllQuery - \(hideEmptyTags)")
    return .run(priority: .utility, name: "updateFetchAllQuery") { [tagInfos = state.$tagInfos] _ in
      @Shared(.hideEmptyTags) var hideEmptyTags
      if hideEmptyTags {
        try await tagInfos.load(TagInfo.queryNonZero)
      } else {
        try await tagInfos.load(TagInfo.queryAll)
      }
    }.cancellable(id: CancelId.tagsListUpdateFetchAllQuery, cancelInFlight: true)
  }
}

public struct TagsListView: View {
  @State private var store: StoreOf<TagsList>
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
    .animation(.smooth, value: store.tagInfos)
    .task { await store.send(.initialize).finish() }
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

private let log: Logger = .init(category: "TagsList")

#if DEBUG

extension TagsListView {

  static var preview: some View {
    prepareDependencies {
      $0.defaultDatabase = previewDatabase()
      // swiftlint:disable:next force_try
      let tag = try! Tag.make(displayName: "Another Tag")
      Operations.tagSoundFont(tag.id, soundFontId: 1)
    }

    return VStack {
      @Shared(.hideEmptyTags) var hideEmptyTags
      Toggle(
        "Hide empty tags",
        isOn: Binding(
          get: { hideEmptyTags },
          set: { newValue in $hideEmptyTags.withLock { $0 = newValue }}
        )
      )
      TagsListView(store: Store(initialState: .init()) { TagsList() })
    }
  }
}

#Preview {
  TagsListView.preview
}

#endif // DEBUG
