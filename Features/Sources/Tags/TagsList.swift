// Copyright © 2025 Brad Howes. All rights reserved.

public import CasePaths
import Combine
public import ComposableArchitecture
import FeatureSupport
public import Models
import SQLiteData
public import SwiftUI
public import Tagged

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
    case deinitialize
    case delegate(Delegate)
    case destination(PresentationAction<Destination.Action>)
    case fullStateChanged(Tag.ID)
    case importFinished
    case initialize
    case tagInfoButtonTapped(TagInfo)
    case tagInfoDeleteTapped(TagInfo)
    case tagInfoEditTapped(TagInfo?)
    case updateFetchAllQuery

    @CasePathable
    public enum Delegate: Equatable {
      case activeTagIdChanged(Tag.ID)
      case edit(focus: Int?)
    }
  }

  public init() {}

  public var body: some ReducerOf<Self> {

    Reduce<State, Action> { state, action in
      log.action("TagsList", action)
      return switch action {
      case .deinitialize: .merge(CancelId.allCases.map { .cancel(id: $0) })
      case .delegate: .none
      case .destination(.dismiss): .none
      case .destination(.presented(.alert(.deleteTagConfirmed(let tagInfo)))): deleteTagConfirmed(&state, tagInfo: tagInfo)
      case .fullStateChanged(let tagId): fullStateChanged(&state, tagId: tagId)
      case .importFinished: importFinished(&state)
      case .initialize: initialize(&state)
      case .tagInfoButtonTapped(let tagInfo): tagInfoButtonTapped(&state, tagInfo: tagInfo)
      case .tagInfoDeleteTapped(let tagInfo): tagInfoDeleteTapped(&state, tagInfo: tagInfo)
      case .tagInfoEditTapped(let tagInfo): tagInfoEditTapped(&state, tagInfo: tagInfo)
      case .updateFetchAllQuery: updateFetchAllQuery(&state)
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

  public static func tagNameToTagId(_ state: inout State, tagName: String) -> Tag.ID {
    for row in state.rows where row.displayName == tagName {
      return row.id
    }
    return Tag.Ubiquitous.all.id
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

  private func fullStateChanged(_ state: inout State, tagId: Tag.ID) -> Effect<Action> {
    state.activeTagId = tagId
    return .none
  }

  private func importFinished(_ state: inout State) -> Effect<Action> {
    if state.activeTagId != Tag.Ubiquitous.all.id && state.activeTagId != Tag.Ubiquitous.added.id {
      state.activeTagId = Tag.Ubiquitous.added.id
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
    .run { send in
      @Shared(.hideBuiltinFonts) var hideBuiltinFonts
      @Shared(.hideEmptyTags) var hideEmptyTags
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

  private func tagInfoEditTapped(_ state: inout State, tagInfo: TagInfo?) -> Effect<Action> {
    return .run { send in
      await send(.delegate(.edit(focus: tagInfo?.ordering)), animation: .smooth)
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
            TagButtonView(store: store, tagInfo: row, indicatorModifierState: indicatorState(for: row.id))
          }
        }
      } header: {
        StyledHeader {
          Text("Tags")
            .onTapGesture(count: 2) {
              store.send(.tagInfoEditTapped(nil))
            }
        }
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

private struct TagButtonView: View {
  private let store: StoreOf<TagsList>
  private let tagInfo: TagInfo
  private let indicatorModifierState: IndicatorModifier.State
  private let count: String

  init(store: StoreOf<TagsList>, tagInfo: TagInfo, indicatorModifierState: IndicatorModifier.State) {
    self.store = store
    self.tagInfo = tagInfo
    self.indicatorModifierState = indicatorModifierState
    self.count = tagInfo.soundFontsCount > 0 ? "\(tagInfo.soundFontsCount)" : ""
  }

  var body: some View {
    Button {
      store.send(.tagInfoButtonTapped(tagInfo))
    } label: {
      HStack {
        Text(tagInfo.displayName)
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
          .onEnded { _ in store.send(.tagInfoEditTapped(tagInfo)) }
      )
    }
    .disabled(count.isEmpty)
    .swipeActions(edge: .leading, allowsFullSwipe: false) {
      Button {
        store.send(.tagInfoEditTapped(tagInfo), animation: .default)
      } label: {
        Image(systemName: .editButtonImageName)
          .tint(.cyan)
      }
    }
    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
      if !tagInfo.isUbiquitous {
        Button {
          store.send(.tagInfoDeleteTapped(tagInfo), animation: .default)
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
      @Binding($hideEmptyTags) var hideEmptyTags
      Toggle("Hide empty tags", isOn: $hideEmptyTags)
        .padding([.leading, .trailing], 16)
      @Binding($hideBuiltinFonts) var hideBuiltinFonts
      Toggle("Hide built-in fonts", isOn: $hideBuiltinFonts)
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
