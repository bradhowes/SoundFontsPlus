// Copyright © 2025 Brad Howes. All rights reserved.

import AsyncAlgorithms
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
      @Shared(.hideEmptyTags) var hideEmptyTags
      let tagInfos: [TagInfo]?
      if hideEmptyTags {
        tagInfos = withDatabaseReader { db in
          try TagInfo.queryNonEmpty.fetchAll(db)
        }
      } else {
        tagInfos = withDatabaseReader { db in
          try TagInfo.queryAll.fetchAll(db)
        }
      }
      self.rows = .init(uniqueElements: (tagInfos ?? []).map { .init(tagInfo: $0) })
    }
  }

  public enum Action {
    case deinitialize
    case delegate(Delegate)
    case destination(PresentationAction<Destination.Action>)
    case fetchAllQueryChanged
    case initialize
    case rows(IdentifiedActionOf<TagButton>)
    case rowsUpdated([TagInfo])

    @CasePathable
    public enum Delegate: Equatable {
      case edit(focus: Int)
    }
  }

  public init() {}

  @Shared(.activeState) private var activeState
  @Shared(.hideBuiltinFonts) public var hideBuiltinFonts
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

      case .fetchAllQueryChanged:
        return updateFetchAllQuery(&state)

      case .initialize:
        return initialize(&state)

      case .rows(.element(_, .delegate(let action))):
        return processRowAction(&state, action: action)

      case .rowsUpdated(let tagInfos):
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
    case tagsListMonitorHideEmptyTags
    case tagsListMonitorHideBuiltinFonts
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
    monitorQueryDependecies(&state)
  }

  private func monitorQueryDependecies(_ state: inout State) -> Effect<Action> {
    .run { [$hideEmptyTags, $hideBuiltinFonts] send in
      for await _ in merge(
        UncheckedSendable($hideEmptyTags.publisher.values),
        UncheckedSendable($hideBuiltinFonts.publisher.values)
      ) {
        await send(.fetchAllQueryChanged)
      }
    }.cancellable(id: CancelId.tagsListMonitorHideEmptyTags)
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
        try await $query.load(TagInfo.queryNonEmpty)
      } else {
        try await $query.load(TagInfo.queryAll)
      }
      for await rows in $query.publisher.values {
        await send(.rowsUpdated(rows))
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
  @Bindable private var store: StoreOf<TagsList>

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

    @Shared(.hideEmptyTags) var hideEmptyTags
    $hideEmptyTags.withLock { $0 = false }

    return VStack {
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
