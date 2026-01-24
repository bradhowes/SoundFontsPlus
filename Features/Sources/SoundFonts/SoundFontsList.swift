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
      case deleteSoundFontCollectionConfirmed([SoundFontInfo])
    }
  }

  @ObservableState
  public struct State: Equatable {
    @Presents public var destination: Destination.State?
    public var rows: IdentifiedArrayOf<SoundFontButton.State>
    public var editingMode: EditMode

    public init(destination: Destination.State? = nil, editingMode: EditMode = .inactive) {
      let soundFontInfos: [SoundFontInfo] = withDatabaseReader { db in
        try SoundFontInfo.query().fetchAll(db)
      } ?? []
      self.rows = .init(uncheckedUniqueElements: soundFontInfos.map { .init(soundFontInfo: $0) })
      self.editingMode = editingMode
    }
  }

  public enum Action: BindableAction {
    case binding(BindingAction<State>)
    case delegate(Delegate)
    case deleteModeCancelButtonTapped
    case deleteModeDeleteButtonTapped
    case deinitialize
    case destination(PresentationAction<Destination.Action>)
    case headerDoubleTapped
    case initialize
    case rows(IdentifiedActionOf<SoundFontButton>)
    case rowsUpdated([SoundFontInfo])
    case showActiveSoundFont
    case updateFetchAllQuery

    @CasePathable
    public enum Delegate: Equatable {
      case edit(SoundFont)
    }
  }

  public init() {}

  @Dependency(\.defaultDatabase) private var database
  @Shared(.activeState) private var activeState
  @Shared(.hideBuiltinFonts) private var hideBuiltinFonts
  @Shared(.selectedSoundFontId) private var selectedSoundFontId

  public var body: some ReducerOf<Self> {
    BindingReducer()

    Reduce { state, action in
      log.action("SoundFontsList", action)

      switch action {

      case .deinitialize:
        return .merge(CancelId.allCases.map { .cancel(id: $0) })

      case .deleteModeCancelButtonTapped:
        state.editingMode = .inactive
        return .none

      case .deleteModeDeleteButtonTapped:
        let selected = state.rows
          .filter { $0.deleting }
          .map { $0.soundFontInfo }
        if !selected.isEmpty {
          state.destination = .alert(.confirmDeleteSoundFontCollection(
            action: .deleteSoundFontCollectionConfirmed(selected),
            count: selected.count
          ))
        } else {
          state.editingMode = .inactive
        }
        return .none

      case .destination(.presented(.alert(.deleteSoundFontConfirmed(let soundFontInfo)))):
        return deleteSoundFontConfirmed(&state, soundFontInfo: soundFontInfo)

      case .destination(.presented(.alert(.deleteSoundFontCollectionConfirmed(let soundFontInfos)))):
        state.editingMode = .inactive
        return deleteSoundFontCollectionConfirmed(&state, soundFontInfos: soundFontInfos)

      case .destination(.dismiss):
        state.editingMode = .inactive
        return .none

      case .headerDoubleTapped:
        state.editingMode = .active
        return .none

      case .initialize:
        return .merge(
          monitorActiveTag(&state),
          monitorHideBuiltinFonts(&state)
        )

      case .rows(.element(_, .delegate(let action))):
        return processRowAction(&state, action: action)

      case .rowsUpdated(let soundFontInfos):
        return soundFontInfosChanged(&state, soundFontInfos: soundFontInfos)

      case .showActiveSoundFont:
        return showActiveSoundFont(&state)

      case .updateFetchAllQuery:
        return updateFetchAllQuery()

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
    case soundFontsListMonitorHideBuiltinFonts
    case soundFontsListUpdateFetchAll
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

  private func confirmDeleteSoundFont(_ state: inout State, soundFontInfo: SoundFontInfo) -> Effect<Action> {
    state.destination = .alert(
      .confirmDeleteSoundFont(
        action: .deleteSoundFontConfirmed(soundFontInfo),
        displayName: soundFontInfo.displayName
      )
    )
    return .none
  }

  private func deleteSoundFontCollectionConfirmed(_ state: inout State, soundFontInfos: [SoundFontInfo]) -> Effect<Action> {
    @Dependency(\.fileManager) var fileManager
    state.editingMode = .inactive
    for soundFontInfo in soundFontInfos {
      guard let soundFont = SoundFont.with(id: soundFontInfo.id ) else {
        log.error("unexpected missing soundfont ID \(soundFontInfo.id)")
        continue
      }

      guard
        let kind = try? SoundFontKind(kind: soundFont.kind, location: soundFont.location, displayName: soundFontInfo.displayName)
      else {
        log.error("unexpected nil kind value for soundfont ID \(soundFontInfo.id)")
        continue
      }

      guard !kind.isBuiltin else {
        log.error("unexpected kind value for soundfont ID \(soundFontInfo.id) - \(String(describing: kind), privacy: .public)")
        continue
      }

      if kind.deleteWhenRemoved {
        do {
          log.info("removing file \(kind.url)")
          try fileManager.removeItem(kind.url)
        } catch {
          log.error("failed to remove item \(kind.url)")
        }
      }

      log.info("removing db entry for \(soundFont.displayName)")
      SoundFont.delete(id: soundFontInfo.id)

      deleted(soundFontInfo.id)
    }

    return showActiveSoundFont(&state)
  }

  private func deleteSoundFontConfirmed(_ state: inout State, soundFontInfo: SoundFontInfo) -> Effect<Action> {
    @Dependency(\.fileManager) var fileManager
    guard let soundFont = SoundFont.with(id: soundFontInfo.id ) else {
      log.error("unexpected missing soundfont ID \(soundFontInfo.id)")
      state.destination = .alert(.genericDeleteFailure("Sound font ID \(soundFontInfo.id) was not found."))
      return .none
    }

    guard
      let kind = try? SoundFontKind(kind: soundFont.kind, location: soundFont.location, displayName: soundFontInfo.displayName)
    else {
      log.error("unexpected nil kind value for soundfont ID \(soundFontInfo.id)")
      state.destination = .alert(.genericDeleteFailure("Invalid (nil) sound font 'kind' value."))
      return .none
    }

    guard !kind.isBuiltin else {
      log.error("unexpected kind value for soundfont ID \(soundFontInfo.id) - \(String(describing: kind), privacy: .public)")
      state.destination = .alert(.genericDeleteFailure("Cannot delete built-in sound fonts."))
      return .none
    }

    if kind.deleteWhenRemoved {
      do {
        log.info("removing file \(kind.url)")
        try fileManager.removeItem(kind.url)
      } catch {
        log.error("failed to remove item \(kind.url)")
        state.destination = .alert(.genericDeleteFailure(
          "Failed to remove sound font file at \(kind.url) - \(error.localizedDescription)."
        ))
      }
    }

    log.info("removing db entry for \(soundFont.displayName)")
    SoundFont.delete(id: soundFontInfo.id)

    deleted(soundFontInfo.id)

    return showActiveSoundFont(&state)
  }

  private func deleted(_ soundFontId: SoundFont.ID) {
    if activeState.activeSoundFontId == soundFontId {
      $activeState.withLock {
        $0.activeSoundFontId = nil
        $0.activePresetId = nil
      }
    }

    if selectedSoundFontId == soundFontId {
      $selectedSoundFontId.withLock {
        $0 = nil
      }
    }
  }

  private func edit(_ state: inout State, soundFontId: SoundFont.ID) -> Effect<Action> {
    if let soundFont = SoundFont.with(id: soundFontId) {
      return .send(.delegate(.edit(soundFont)))
    }
    return .none
  }

  private func processRowAction(_ state: inout State, action: SoundFontButton.Delegate) -> Effect<Action> {
    log.action("processRowAction", action)

    switch action {

    case .alertInvalidBookmark(let soundFontInfo):
      return alertInvalidBookmark(&state, soundFontInfo: soundFontInfo)

    case .alertMissingFile(let soundFontInfo):
      return alertMissingFile(&state, soundFontInfo: soundFontInfo)

    case .deleteSoundFont(let soundFontInfo):
      return confirmDeleteSoundFont(&state, soundFontInfo: soundFontInfo)

    case .editSoundFont(let soundFontInfo):
      return edit(&state, soundFontId: soundFontInfo.id)

    case .selectSoundFont(let soundFontInfo, let available):
      return select(soundFontId: soundFontInfo.id, available: available)
    }
  }

  private func monitorActiveTag(_ state: inout State) -> Effect<Action> {
    .run { [$activeState] send in
      for await _ in UncheckedSendable($activeState.activeTagId.publisher.values.removeDuplicates()) {
        await send(.updateFetchAllQuery)
      }
    }.cancellable(id: CancelId.soundFontsListMonitorActiveTagId, cancelInFlight: true)
  }

  private func monitorHideBuiltinFonts(_ state: inout State) -> Effect<Action> {
    .run { [$hideBuiltinFonts] send in
      for await _ in UncheckedSendable($hideBuiltinFonts.publisher.values.removeDuplicates()) {
        await send(.updateFetchAllQuery)
      }
    }.cancellable(id: CancelId.soundFontsListMonitorHideBuiltinFonts)
  }

  private func select(soundFontId: SoundFont.ID, available: Bool) -> Effect<Action> {
    if selectedSoundFontId != soundFontId && available {
      $selectedSoundFontId.withLock { $0 = soundFontId }
    }
    return .none
  }

  private func showActiveSoundFont(_ state: inout State) -> Effect<Action> {
    if let activeSoundFontId = activeState.activeSoundFontId,
       let index = state.rows.index(id: activeSoundFontId) {
      return select(soundFontId: activeSoundFontId, available: state.rows[index].statusInfoTag.available)
    } else {
      return .none
    }
  }

  private func soundFontInfosChanged(_ state: inout State, soundFontInfos: [SoundFontInfo]) -> Effect<Action> {
    let update = IdentifiedArrayOf<SoundFontButton.State>(uncheckedUniqueElements: soundFontInfos.map { .init(soundFontInfo: $0) })
    if state.rows != update {
      state.rows = update
    }
    return .none
  }

  private func updateFetchAllQuery() -> Effect<Action> {
    .run(priority: .utility, name: "monitorFetchAll") { send in
      @FetchAll var soundFontInfos: [SoundFontInfo]
      try await $soundFontInfos.load(SoundFontInfo.query())
      for try await rows in $soundFontInfos.publisher.values {
        await send(.rowsUpdated(rows))
      }

    }.cancellable(id: CancelId.soundFontsListUpdateFetchAll, cancelInFlight: true)
  }
}

extension SoundFontsList.Destination.State: Equatable {}
extension SoundFontsList.Destination.State: _EphemeralState {
  public typealias Action = Alert
}

// MARK: - View

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
        StyledHeader {
          ZStack(alignment: .leadingFirstTextBaseline) {
            Text("Files")
              .zIndex(1)
              .opacity(store.editingMode == .active ? 0.0 : 1.0)
              .onTapGesture(count: 2) {
                store.send(.headerDoubleTapped)
              }
            HStack(spacing: 16) {
              Button {
                store.send(.deleteModeCancelButtonTapped)
              } label: {
                Text("Cancel")
              }
              Button {
                store.send(.deleteModeDeleteButtonTapped)
              } label: {
                Text("Delete")
                  .foregroundStyle(.red)
              }
            }
            .zIndex(2)
            .opacity(store.editingMode == .active ? 1.0 : 0.0)
          }
        }
      }
    }
    .environment(\.editMode, $store.editingMode)
    .animation(.smooth, value: store.editingMode)
    .animation(.smooth, value: store.rows)
    .task { await store.send(.initialize).finish() }
    .alert($store.scope(state: \.destination?.alert, action: \.destination.alert))
  }
}

private let log: Logger = .init(category: "SoundFontsList")

#if DEBUG

extension SoundFontsListView {
  static var preview: some View {
    prepareDependencies {
      @Shared(.hideBuiltinFonts) var hideBuiltinFonts = false
      @Shared(.hideEmptyTags) var hideEmptyTags = false
      $0.defaultDatabase = previewDatabase()
    }

    // swiftlint:disable:next force_try
    let tag = try! Tag.make(displayName: "My Tag")
    Operations.tagSoundFont(tag.id, soundFontId: 2)

    return VStack {
      SoundFontsListView(store: Store(initialState: .init()) { SoundFontsList() })
      TagsListView(store: Store(initialState: .init()) { TagsList() })
    }
  }
}

#Preview {
  SoundFontsListView.preview
}

#endif // DEBUG
