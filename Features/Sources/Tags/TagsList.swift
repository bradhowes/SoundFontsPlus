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
    public var activeTagId: Tag.ID = Tag.Ubiquitous.all.id
    public var activeTagName: String? { self.rows[id: activeTagId]?.tagInfo.displayName }
    public var rows: IdentifiedArrayOf<TagButton.State>
    @Presents public var destination: Destination.State?

    public init(activeTagId: Tag.ID? = nil) {
      self.activeTagId = activeTagId ?? Tag.Ubiquitous.all.id
      self.rows = .init(uniqueElements: [])
    }
  }

  public enum Action {
    case activeTagIdChanged(Tag.ID)
    case activeTagNameChanged(String)
    case deinitialize
    case delegate(Delegate)
    case destination(PresentationAction<Destination.Action>)
    case fetchAllQueryChanged
    case importFinished
    case initialize
    case rows(IdentifiedActionOf<TagButton>)
    case rowsUpdated([TagInfo])

    @CasePathable
    public enum Delegate: Equatable {
      case activeTagIdChanged(Tag.ID)
      case edit(focus: Int)
    }
  }

  public init() {}

  @Shared(.hideBuiltinFonts) public var hideBuiltinFonts
  @Shared(.hideEmptyTags) public var hideEmptyTags

  public var body: some ReducerOf<Self> {

    Reduce<State, Action> { state, action in

      log.action("TagsList", action)

      switch action {

      case .activeTagIdChanged(let tagId):
        return activeTagIdChanged(&state, tagId: tagId)

      case .activeTagNameChanged(let tagName):
        return activeTagNameChanged(&state, tagName: tagName)

      case .deinitialize:
        return .merge(CancelId.allCases.map { .cancel(id: $0) })

      case .delegate:
        return .none

      case .destination(.presented(.alert(.deleteTagConfirmed(let tagInfo)))):
        return deleteTagConfirmed(&state, tagInfo: tagInfo)

      case .fetchAllQueryChanged:
        return fetchAllQueryChanged(&state)

      case .importFinished:
        if state.activeTagId != Tag.Ubiquitous.all.id && state.activeTagId != Tag.Ubiquitous.added.id {
          state.activeTagId = Tag.Ubiquitous.added.id
        }
        return .send(.delegate(.activeTagIdChanged(state.activeTagId)))

      case .initialize:
        return initialize(&state)

      case .rows(.element(_, .delegate(let action))):
        return processRowAction(&state, action: action)

      case .rowsUpdated(let tagInfos):
        return rowsUpdated(&state, tagInfos: tagInfos)

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

  private func activeTagIdChanged(_ state: inout State, tagId: Tag.ID) -> Effect<Action> {
    state.activeTagId = tagId
    return .none
  }

  private func activeTagNameChanged(_ state: inout State, tagName: String) -> Effect<Action> {
    for row in state.rows where row.tagInfo.displayName == tagName {
      state.activeTagId = row.tagInfo.id
      return .send(.delegate(.activeTagIdChanged(state.activeTagId)))
    }
    return .none
  }

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
    try? Tag.delete(id: tagInfo.id)

    if state.activeTagId == tagInfo.id {
      state.activeTagId = Tag.Ubiquitous.all.id
      return .send(.delegate(.activeTagIdChanged(state.activeTagId)))
    }

    return .none
  }

  private func fetchAllQueryChanged(_ state: inout State) -> Effect<Action> {
    .run(priority: .utility, name: "fetchAllQueryChanged") { send in
      @FetchAll var query: [TagInfo]
      try await $query.load(TagInfo.query)
      if Task.isCancelled { return }
      for await rows in $query.publisher.values {
        if Task.isCancelled { break }
        await send(.rowsUpdated(rows))
      }
    }.cancellable(id: CancelId.tagsListUpdateFetchAllQuery, cancelInFlight: true)
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
      state.activeTagId = tagInfo.id
      return .send(.delegate(.activeTagIdChanged(state.activeTagId)))

    case .delete(let tagInfo):
      if tagInfo.soundFontsCount > 0 {
        return confirmDeleteTag(&state, tagInfo: tagInfo)
      }
      return deleteTagConfirmed(&state, tagInfo: tagInfo)

    case .edit(let tagInfo):
      return .run { send in
        await send(.delegate(.edit(focus: tagInfo.ordering)), animation: .smooth)
      }
    }
  }

  private func rowsUpdated(_ state: inout State, tagInfos: [TagInfo]) -> Effect<Action> {
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
            TagButtonView(store: rowStore, indicatorModifierState: indicatorState(for: rowStore.id))
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

  private func indicatorState(for tagId: Tag.ID) -> IndicatorModifier.State {
    tagId == store.activeTagId ? .active : .none
  }
}

private let log: Logger = .init(category: "TagsList")

#if DEBUG

extension TagsListView {

  static var preview: some View {
    @Shared(.hideEmptyTags) var hideEmptyTags
    $hideEmptyTags.withLock { $0 = false }
    @Shared(.hideBuiltinFonts) var hideBuiltinFonts
    $hideBuiltinFonts.withLock { $0 = false }

    return VStack {
      Toggle(
        "Hide empty tags",
        isOn: Binding(
          get: { hideEmptyTags },
          set: { newValue in $hideEmptyTags.withLock { $0 = newValue }}
        )
      )
      .padding([.leading, .trailing], 16)
      Toggle(
        "Hide built-in fonts",
        isOn: Binding(
          get: { hideBuiltinFonts },
          set: { newValue in $hideBuiltinFonts.withLock { $0 = newValue }}
        )
      )
      .padding([.leading, .trailing], 16)
      TagsListView(store: Store(initialState: .init(activeTagId: nil)) { TagsList() })
    }
  }
}

#Preview {
  // swiftlint:disable:next redundant_discardable_let
  let _ = prepareDependencies {
    installApplicationFont()
    $0.defaultDatabase = previewDatabase()
    _ = try? Tag.make(displayName: "Empty Tag")
    if let tag = try? Tag.make(displayName: "Another Tag") {
      SoundFont.link(soundFontId: 1, to: tag.id)
    }
  }
  TagsListView.preview
    .environment(\.font, Font.body)
}

#endif // DEBUG
