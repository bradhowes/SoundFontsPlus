// Copyright © 2025 Brad Howes. All rights reserved.

import FeatureSupport
import SQLiteData

/**
 Feature that shows a list of tag buttons.

 - Touching a button makes the associated tag active, and this will affect which fonts are shown in the font view
 - Swiping left offers a button to edit the tags
 - Swiping right shows a button to delete a user's tag
 - Long-press on a tag to show the tag editor
 */
@Reducer
public struct TagsList {

  @Reducer
  public enum Destination {
    case alert(AlertState<Alert>)

    @CasePathable
    public enum Alert: Equatable {
      case deleteTagConfirmed(TagInfo)
    }
  }

  @ObservableState
  public struct State: Equatable {
    public var rows: IdentifiedArrayOf<TagButton.State>
    @Presents public var destination: Destination.State?

    public init() {
      rows = .init()
    }
  }

  public enum Action {
    case deinitialize
    case delegate(Delegate)
    case destination(PresentationAction<Destination.Action>)
    case initialize
    case rows(IdentifiedActionOf<TagButton>)
    case updateFetchAllQuery
    case updateRows([TagInfo])

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

      case .deinitialize:
        return .merge(CancelId.allCases.map { .cancel(id: $0) })

      case .delegate:
        return .none

      case .destination(.presented(.alert(.deleteTagConfirmed(let tagInfo)))):
        return deleteTagConfirmed(&state, tagInfo: tagInfo)

      case .initialize:
        return initialize(&state)

      case .rows(.element(_, .delegate(let action))):
        return processRowAction(&state, action: action)

      case .updateFetchAllQuery:
        return updateFetchAllQuery(&state)

      case .updateRows(let tagInfos):
        return updateRows(&state, tagInfos: tagInfos)

      default:
        return .none
      }
    }
    .forEach(\.rows, action: \.rows) {
      TagButton()
    }
    .ifLet(\.destination, action: \.destination)
  }

  private enum CancelId: CaseIterable {
    case taskListMonitorHideEmptyTags
    case tagsListUpdateFetchAllQuery
  }
}

extension TagsList {

  private func confirmDeleteTag(_ state: inout State, tagInfo: TagInfo) -> Effect<Action> {
    state.destination = .alert(
      .confirmDeleteTag(
        action: .deleteTagConfirmed(tagInfo),
        displayName: tagInfo.displayName,
        associationCount: tagInfo.soundFontsCount
      )
    )
    return .none
  }

  private func deleteTagConfirmed(_ state: inout State, tagInfo: TagInfo) -> Effect<Action> {
    if activeState.activeTagId == tagInfo.id {
      $activeState.withLock { $0.activeTagId = Tag.Ubiquitous.all.id }
    }

    try? Tag.delete(id: tagInfo.id)

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
          return .updateFetchAllQuery
        }
    }.cancellable(id: CancelId.taskListMonitorHideEmptyTags)
  }

  private func processRowAction(_ state: inout State, action: TagButton.Delegate) -> Effect<Action> {
    log.action("processRowAction", action)
    switch action {

    case .activate(let tagInfo):
      $activeState.withLock { $0.activeTagId = tagInfo.id }
      return .none

    case .delete(let tagInfo):
      if tagInfo.soundFontsCount > 0 {
        return confirmDeleteTag(&state, tagInfo: tagInfo)
      }
      return deleteTagConfirmed(&state, tagInfo: tagInfo)

    case .edit(let tagInfo):
      return .send(.delegate(.edit(focus: tagInfo.ordering)), animation: .smooth)

    }
  }

  private func updateFetchAllQuery(_ state: inout State) -> Effect<Action> {
    .run(priority: .utility, name: "updateFetchAllQuery") { send in
      @Shared(.hideEmptyTags) var hideEmptyTags
      @FetchAll var query: [TagInfo]
      if hideEmptyTags {
        try await $query.load(TagInfo.queryNonZero)
      } else {
        try await $query.load(TagInfo.queryAll)
      }
      for await update in $query.publisher.values {
        await send(.updateRows(update))
      }
    }.cancellable(id: CancelId.tagsListUpdateFetchAllQuery, cancelInFlight: true)
  }

  private func updateRows(_ state: inout State, tagInfos: [TagInfo]) -> Effect<Action> {
    withAnimation(.smooth) {
      state.rows = .init(uniqueElements: tagInfos.map { .init(tagInfo: $0) })
    }
    return .none
  }
}

extension TagsList.Destination.State: Equatable {}
extension TagsList.Destination.State: _EphemeralState {
  public typealias Action = Alert
}

// MARK: - View

public struct TagsListView: View {
  @State private var store: StoreOf<TagsList>

  public init(store: StoreOf<TagsList>) {
    self.store = store
  }

  public var body: some View {
    StyledList {
      Section {
        ForEach(store.scope(state: \.rows, action: \.rows)) { rowStore in
          StyledEntry {
            TagButtonView(store: rowStore)
          }
        }
      } header: {
        StyledHeader { Text("Tags") }
      }
    }
    .animation(.smooth, value: store.rows)
    .task { await store.send(.initialize).finish() }
    .alert($store.scope(state: \.destination?.alert, action: \.destination.alert))
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
