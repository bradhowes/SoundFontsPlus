// Copyright © 2025 Brad Howes. All rights reserved.

import FeatureSupport
import SQLiteData
import Tags

@Reducer
public struct SoundFontsList {

  @Reducer
  public enum Destination {
    case alert(AlertState<Alert>)

    @CasePathable
    public enum Alert: Equatable {
      case deleteSoundFontConfirmed(SoundFontInfo)
    }
  }

  @ObservableState
  public struct State: Equatable {
    @Presents public var destination: Destination.State?
    public var rows: IdentifiedArrayOf<SoundFontButton.State>

    public init(destination: Destination.State? = nil) {
      @FetchAll(SoundFontInfo.query()) var soundFontInfos
      log.info("init \(soundFontInfos)")
      self.rows = .init(uncheckedUniqueElements: soundFontInfos.map { .init(soundFontInfo: $0) })
    }
  }

  public enum Action {
    case activeTagIdChanged
    case delegate(Delegate)
    case deinitialize
    case destination(PresentationAction<Destination.Action>)
    case initialize
    case rows(IdentifiedActionOf<SoundFontButton>)
    case showActiveSoundFont
    case soundFontInfosChanged([SoundFontInfo])

    @CasePathable
    public enum Delegate: Equatable {
      case edit(SoundFont)
    }
  }

  public init() {}

  @Dependency(\.defaultDatabase) private var database
  @Shared(.selectedSoundFontId) private var selectedSoundFontId
  @Shared(.activeState) private var activeState

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      log.info("SoundFontsList reduce \(action)")

      switch action {

      case .activeTagIdChanged:
        return monitorFetchAll(&state)

      case .deinitialize:
        return .merge(CancelId.allCases.map { .cancel(id: $0) })

      case .destination(.presented(.alert(.deleteSoundFontConfirmed(let soundFontInfo)))):
        SoundFont.delete(id: soundFontInfo.id)
        return .none

      case .initialize:
        return .merge(
          monitorActiveTag(&state),
          monitorFetchAll(&state)
        )

      case .rows(.element(_, .delegate(let action))):
        return processRowAction(&state, action: action)

      case .showActiveSoundFont:
        return showActiveSoundFont(&state)

      case .soundFontInfosChanged(let soundFontInfos):
        return soundFontInfosChanged(&state, soundFontInfos: soundFontInfos)

      default:
        return .none
      }
    }
    .forEach(\.rows, action: \.rows) {
      SoundFontButton()
    }
    .ifLet(\.destination, action: \.destination)
  }

  private enum CancelId: String, CaseIterable {
    case soundFontsListMonitorActiveTagId
    case soundFontsListMonitorFetchAll
  }
}

extension SoundFontsList {

  private func alertInvalidBookmark(_ state: inout State, soundFontInfo: SoundFontInfo) -> Effect<Action> {
    state.destination = .alert(.invalidBookmark(displayName: soundFontInfo.displayName))
    return .none
  }

  private func alertMissingFile(_ state: inout State, soundFontInfo: SoundFontInfo) -> Effect<Action> {
    state.destination = .alert(.missingFile(displayName: soundFontInfo.displayName))
    return .none
  }

  private func deleteSoundFont(_ state: inout State, soundFontInfo: SoundFontInfo) -> Effect<Action> {
    state.destination = .alert(
      .confirmDeleteSoundFont(
        action: .deleteSoundFontConfirmed(soundFontInfo),
        displayName: soundFontInfo.displayName
      )
    )
    return .none
  }

  private func edit(_ state: inout State, soundFontId: SoundFont.ID) -> Effect<Action> {
    if let soundFont = SoundFont.with(id: soundFontId) {
      return .send(.delegate(.edit(soundFont)))
    }
    return .none
  }

  private func processRowAction(_ state: inout State, action: SoundFontButton.Delegate) -> Effect<Action> {
    log.info("processRowAction: \(action)")

    switch action {

    case .alertInvalidBookmark(let soundFontInfo):
      return alertInvalidBookmark(&state, soundFontInfo: soundFontInfo)

    case .alertMissingFile(let soundFontInfo):
      return alertMissingFile(&state, soundFontInfo: soundFontInfo)

    case .deleteSoundFont(let soundFontInfo):
      return deleteSoundFont(&state, soundFontInfo: soundFontInfo)

    case .editSoundFont(let soundFontInfo):
      return edit(&state, soundFontId: soundFontInfo.id)

    case .selectSoundFont(let soundFontInfo):
      return select(&state, soundFontId: soundFontInfo.id)
    }
  }

  private func monitorActiveTag(_ state: inout State) -> Effect<Action> {
    log.info("monitorActiveTag")
    return .publisher {
      return $activeState.activeTagId
        .publisher
        .removeDuplicates()
        .map { tagId in
          log.info("activeTagChanged - \(String(describing: tagId))")
          return .activeTagIdChanged
        }
    }.cancellable(id: CancelId.soundFontsListMonitorActiveTagId, cancelInFlight: true)
  }

  private func monitorFetchAll(_ state: inout State) -> Effect<Action> {
    .run(priority: .utility, name: "monitorFetchAll") { send in
      // Update a query for the SoundFont list view. When the DB changes, this will emit a `soundFontInfoChanged` action
      // causing the rows to change. The query depends on the value of `activeState.activeTagId` so when that changes,
      // `monitorFetchAll` reruns which cancels the old query and installs a new one.
      @FetchAll(SoundFontInfo.query()) var soundFontInfos

      // Make sure we are reading from the latest value of `activeState.activeTagId` before processing
      try await $soundFontInfos.load(SoundFontInfo.query())

      // When the query results change, send them into the reducer to create a new collection of rows
      for try await update in $soundFontInfos.publisher.values {
        await send(.soundFontInfosChanged(update))
      }
    }.cancellable(id: CancelId.soundFontsListMonitorFetchAll, cancelInFlight: true)
  }

  private func select(_ state: inout State, soundFontId: SoundFont.ID) -> Effect<Action> {
    if selectedSoundFontId != soundFontId {
      $selectedSoundFontId.withLock { $0 = soundFontId }
    }
    return .none
  }

  private func showActiveSoundFont(_ state: inout State) -> Effect<Action> {
    if let activeSoundFontId = activeState.activeSoundFontId {
      return select(&state, soundFontId: activeSoundFontId)
    } else {
      return .none
    }
  }

  private func soundFontInfosChanged(_ state: inout State, soundFontInfos: [SoundFontInfo]) -> Effect<Action> {
    let update = IdentifiedArrayOf<SoundFontButton.State>(
      uncheckedUniqueElements: soundFontInfos.map {
        .init(soundFontInfo: $0)
      }
    )
    if state.rows != update {
      log.info("replacing rows with changes")
      state.rows = update
    }
    return .none
  }
}

extension SoundFontsList.Destination.State: Equatable {}
extension SoundFontsList.Destination.State: _EphemeralState {
  public typealias Action = Alert
}

public struct SoundFontsListView: View {
  @Bindable private var store: StoreOf<SoundFontsList>

  public init(store: StoreOf<SoundFontsList>) {
    self.store = store
  }

  public var body: some View {
    StyledList {
      Section {
        ForEach(store.scope(state: \.rows, action: \.rows)) { rowStore in
          StyledEntry {
            SoundFontButtonView(store: rowStore)
          }
        }
      } header: {
        StyledHeader { Text("Files") }
      }
    }
    .animation(.smooth, value: store.rows)
    .task {
      await store.send(.initialize).finish()
    }
    .alert($store.scope(state: \.destination?.alert, action: \.destination.alert))
  }
}

extension SoundFontsListView {
  static var preview: some View {
    prepareDependencies {
      $0.defaultDatabase = previewDatabase()
    }

    // swiftlint:disable:next force_try
    let tag = try! FontTag.make(displayName: "My Tag")
    Operations.tagSoundFont(tag.id, soundFontId: 2)

    return VStack {
      SoundFontsListView(store: Store(initialState: .init()) { SoundFontsList() })
      TagsListView(store: Store(initialState: .init()) { TagsList() })
    }
  }
}

private let log = Logger(category: "SoundFontsList")

#Preview {
  SoundFontsListView.preview
}
