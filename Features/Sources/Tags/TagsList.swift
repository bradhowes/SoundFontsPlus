// Copyright © 2025 Brad Howes. All rights reserved.

import FeatureSupport
import SQLiteData

/**
 Feature that shows a list of tag buttons, one per known tag in the database.

 - Touching a button makes the associated tag active, and this will affect which fonts are shown in the font view
 - Swiping right offers a button to edit the tags
 - Swiping left shows a button to delete a user's tag
 - Long-press on any tag to edit the tags

 The number of tags shown is affected by the `hideBuiltinFonts` and `hideEmptyTags` option settings.
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
    @ObservationStateIgnored
    @FetchAll(TagInfo.query) var tagInfos: [TagInfo]
    public var rows: IdentifiedArrayOf<TagInfo> { .init(uniqueElements: tagInfos) }
    public var activeTagId: Tag.ID = Tag.Ubiquitous.all.id
    public var activeTagName: String? { self.rows[id: activeTagId]?.displayName }
    @Presents public var destination: Destination.State?

    public init(activeTagId: Tag.ID? = nil) {
      self.activeTagId = activeTagId ?? Tag.Ubiquitous.all.id
    }
  }

  public enum Action {
    case activeTagIdChanged(Tag.ID)
    case activeTagNameChanged(String)
    case deinitialize
    case delegate(Delegate)
    case destination(PresentationAction<Destination.Action>)
    case importFinished
    case initialize
    case tagInfoButtonTapped(TagInfo)
    case tagInfoDeleteTapped(TagInfo)
    case tagInfoEditTapped(TagInfo)
    case updateFetchAllQuery

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

      case .importFinished:
        if state.activeTagId != Tag.Ubiquitous.all.id && state.activeTagId != Tag.Ubiquitous.added.id {
          state.activeTagId = Tag.Ubiquitous.added.id
          return .send(.delegate(.activeTagIdChanged(state.activeTagId)))
        }
        return .none

      case .initialize:
        return initialize(&state)

      case .tagInfoButtonTapped(let tagInfo):
        return tagInfoButtonTapped(&state, tagInfo: tagInfo)

      case .tagInfoDeleteTapped(let tagInfo):
        return tagInfoDeleteTapped(&state, tagInfo: tagInfo)

      case .tagInfoEditTapped(let tagInfo):
        return tagInfoEditTapped(&state, tagInfo: tagInfo)

      case .updateFetchAllQuery:
        return updateFetchAllQuery(&state)

      default:
        return .none
      }
    }
    .ifLet(\.destination, action: \.destination)
  }

  private enum CancelId: CaseIterable {
    case tagsListMonitorFetchAllQueryOptions
    case tagsListUpdateFetchAllQuery
  }
}

extension TagsList {

  private func activeTagIdChanged(_ state: inout State, tagId: Tag.ID) -> Effect<Action> {
    state.activeTagId = tagId
    return .none
  }

  private func activeTagNameChanged(_ state: inout State, tagName: String) -> Effect<Action> {
    for row in state.rows where row.displayName == tagName {
      state.activeTagId = row.id
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

  private func initialize(_ state: inout State) -> Effect<Action> {
    .merge(
      monitorFetchAllQueryOptions(&state)
    )
  }

  private func monitorFetchAllQueryOptions(_ state: inout State) -> Effect<Action> {
    return .run { [$hideEmptyTags, $hideBuiltinFonts] send in
      var stateMonitor = StateMonitor { [$hideEmptyTags.wrappedValue, $hideBuiltinFonts.wrappedValue] }
      for await _ in $hideEmptyTags.publisher.merge(with: $hideBuiltinFonts.publisher).values where stateMonitor.changed() {
        // We could do the update here directly, but the additional reducer activity allows us to easily test that the monitoring
        // worked.
        await send(.updateFetchAllQuery)
      }
    }.cancellable(id: CancelId.tagsListMonitorFetchAllQueryOptions)
  }

  private func tagInfoButtonTapped(_ state: inout State, tagInfo: TagInfo) -> Effect<Action> {
    state.activeTagId = tagInfo.id
    return .send(.delegate(.activeTagIdChanged(state.activeTagId)))
  }

  private func tagInfoDeleteTapped(_ state: inout State, tagInfo: TagInfo) -> Effect<Action> {
    if tagInfo.soundFontsCount > 0 {
      return confirmDeleteTag(&state, tagInfo: tagInfo)
    }
    return deleteTagConfirmed(&state, tagInfo: tagInfo)
  }

  private func tagInfoEditTapped(_ state: inout State, tagInfo: TagInfo) -> Effect<Action> {
    return .run { send in
      await send(.delegate(.edit(focus: tagInfo.ordering)), animation: .smooth)
    }
  }

  private func updateFetchAllQuery(_ state: inout State) -> Effect<Action> {
    let tagInfos = state.$tagInfos
    return .run(priority: .utility, name: "TagsListUpdateFetchAllQuery") { [tagInfos] _ in
      try await tagInfos.load(TagInfo.query)
    }.cancellable(id: CancelId.tagsListUpdateFetchAllQuery, cancelInFlight: true)
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
        ForEach(store.rows) { row in
          StyledEntry {
            tagButtonView(row: row)
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

  private func tagButtonView(row: TagInfo) -> some View {
    let count = row.soundFontsCount > 0 ? "\(row.soundFontsCount)" : ""
    let indicatorModifierState = indicatorState(for: row.id)
    return Button {
      store.send(.tagInfoButtonTapped(row))
    } label: {
      HStack {
        Text(row.displayName)
          .font(.button)
          .opacity(count.isEmpty ? 0.75 : 1.0)
          .indicator(indicatorModifierState)
        Spacer()
        Text(count)
          .font(.button)
          .indicator(indicatorModifierState == .active ? .activeNoIndicator : .none)
      }
      .contentShape(.interaction, Rectangle())
      .simultaneousGesture(
        LongPressGesture(minimumDuration: 1.0)
          .onEnded { _ in store.send(.tagInfoEditTapped(row)) }
      )
    }
    .disabled(count.isEmpty)
    .swipeActions(edge: .leading, allowsFullSwipe: false) {
      Button {
        store.send(.tagInfoEditTapped(row), animation: .default)
      } label: {
        Image(systemName: .editButtonImageName)
          .tint(.cyan)
      }
    }
    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
      if !row.isUbiquitous {
        Button {
          store.send(.tagInfoDeleteTapped(row), animation: .default)
        } label: {
          Image(systemName: .deleteButtonImageName)
            .tint(.red)
        }
      }
    }
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

    let mine = try? SoundFont.add(
      displayName: "My Font",
      soundFontKind: .installed(filename: SF2ResourceTag.rolandNicePiano.url.lastPathComponent)
    )

    if let tag = try? Tag.make(displayName: "My Tag"), let mine {
      SoundFont.link(soundFontId: mine.id, to: tag.id)
    }

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
    $0.fileManager.fontFilePath = {
      SF2ResourceTag.rolandNicePiano.url.deletingLastPathComponent().appendingPathComponent($0, isDirectory: false)
    }
  }
  TagsListView.preview
    .environment(\.font, Font.body)
}

#endif // DEBUG
