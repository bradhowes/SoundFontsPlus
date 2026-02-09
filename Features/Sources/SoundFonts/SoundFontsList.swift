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
    public var activeTagId: Tag.ID
    public var activePresetSource: PresetSource?
    public var selectedPresetSource: PresetSource?
    public var editingMode: EditMode

    @ObservationStateIgnored
    public var searchSource: IdentifiedArrayOf<SoundFontButton.State>
    public var searchText: String
    public var isSearchFieldPresented: Bool
    public var focusedField: Field?
    @ObservationStateIgnored
    public var lastSearchText: String?

    public enum Field: String, Hashable {
      case searchText
    }

    public init(
      activeTagId: Tag.ID? = nil,
      activePresetSource: PresetSource? = nil,
      selectedPresetSource: PresetSource? = nil,
      destination: Destination.State? = nil,
      editingMode: EditMode = .inactive
    ) {
      self.activeTagId = activeTagId ?? Tag.Ubiquitous.all.id
      self.activePresetSource = activePresetSource
      self.selectedPresetSource = selectedPresetSource

      let soundFontInfos: [SoundFontInfo] = withDatabaseReader { db in
        try SoundFontInfo.query(for: Tag.Ubiquitous.all.id).fetchAll(db)
      } ?? []
      self.rows = .init(uncheckedUniqueElements: soundFontInfos.map { .init(soundFontInfo: $0) })
      self.editingMode = editingMode

      self.searchSource = []
      self.searchText = ""
      self.isSearchFieldPresented = false
    }
  }

  public enum Action: BindableAction {
    case activeTagIdChanged(Tag.ID)
    case binding(BindingAction<State>)
    case cancelSearchButtonTapped
    case clearSearchTextField
    case delegate(Delegate)
    case deleteModeCancelButtonTapped
    case deleteModeDeleteButtonTapped
    case deinitialize
    case destination(PresentationAction<Destination.Action>)
    case headerDoubleTapped
    case initialize
    case missingSoundFontDetected(SoundFont.ID)
    case restoreActiveState(activeTagId: Tag.ID, activePresetSource: PresetSource)
    case rows(IdentifiedActionOf<SoundFontButton>)
    case rowsUpdated([SoundFontInfo])
    case searchButtonTapped
    case searchTextChanged(String)
    case selectedActivated
    case showActiveSoundFont
    case updateFetchAllQuery

    @CasePathable
    public enum Delegate: Equatable {
      case presetSourceChanged(PresetSource?)
      case edit(SoundFont)
    }
  }

  public init() {}

  @Dependency(\.defaultDatabase) private var database
  @Dependency(\.fileManager) private var fileManager

  @Shared(.hideBuiltinFonts) private var hideBuiltinFonts

  public var body: some ReducerOf<Self> {
    BindingReducer()

    Reduce { state, action in
      log.action("SoundFontsList", action)

      switch action {

      case .activeTagIdChanged(let tagId):
        state.activeTagId = tagId
        return updateFetchAllQuery(tagId)

      case .cancelSearchButtonTapped:
        return dismissSearch(&state)

      case .clearSearchTextField:
        return searchTextChanged(&state, searchText: "")

      case .deinitialize:
        return .merge(CancelId.allCases.map { .cancel(id: $0) })

      case .deleteModeCancelButtonTapped:
        state.editingMode = .inactive
        return .none

      case .deleteModeDeleteButtonTapped:
        let selected = state.rows
          .filter(\.deleting)
          .map(\.soundFontInfo)
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
        return .merge(
          state.rows.map {
            reduce(
              into: &state,
              action: .rows(.element(id: $0.id, action: .resetDeleting))
            )
        })

      case .initialize:
        return monitorHideBuiltinFonts(&state)

      case .missingSoundFontDetected(let soundFontId):
        SoundFont.delete(id: soundFontId)
        if state.activePresetSource == .active(soundFontId) {
          state.activePresetSource = nil
        }
        if state.selectedPresetSource == .selected(soundFontId) {
          state.selectedPresetSource = nil
        }
        return .none

      case let .restoreActiveState(activeTagId, activePresetSource):
        state.activeTagId = activeTagId
        state.activePresetSource = activePresetSource
        state.selectedPresetSource = nil
        return .none

      case .rows(.element(_, .delegate(let action))):
        return processRowAction(&state, action: action)

      case .rowsUpdated(let soundFontInfos):
        return soundFontInfosChanged(&state, soundFontInfos: soundFontInfos)

      case .searchButtonTapped:
        return searchButtonTapped(&state)

      case .searchTextChanged(let value):
        return searchTextChanged(&state, searchText: value)

      case .selectedActivated:
        return selectedActivated(&state)

      case .showActiveSoundFont:
        return showActiveSoundFont(&state)

      case .updateFetchAllQuery:
        return updateFetchAllQuery(state.activeTagId)

      default:
        return .none
      }
    }
    .forEach(\.rows, action: \.rows) {
      SoundFontButton()
    }
    // .ifLet(\.destination, action: \.destination)
  }

  private enum CancelId: String, CaseIterable {
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

    let ids = soundFontInfos.map { $0.id }
    withDatabaseWriter { db in
      try SoundFont.delete()
        .where { ids.contains($0.id) }
        .execute(db)
    }

    let urls = soundFontInfos
      .filter { $0.isInstalled }
      .compactMap { try? SoundFontKind(kind: $0.kind, location: $0.location, displayName: $0.displayName).url }

    for url in urls {
      do {
        try fileManager.removeItem(url)
      } catch {
        log.error("failed to remove sound font at \(url): \(error)")
      }
    }

    return showActiveSoundFont(&state)
  }

  private func deleteSoundFontConfirmed(_ state: inout State, soundFontInfo: SoundFontInfo) -> Effect<Action> {
    state.destination = deleteSoundFont(&state, soundFontInfo: soundFontInfo)
    return .merge(deleted(&state, soundFontId: soundFontInfo.id), showActiveSoundFont(&state))
  }

  private func deleteSoundFont(_ state: inout State, soundFontInfo: SoundFontInfo) -> Destination.State? {
    @Dependency(\.fileManager) var fileManager
    guard let soundFont = SoundFont.with(id: soundFontInfo.id ) else {
      log.error("unexpected missing soundfont ID \(soundFontInfo.id)")
      return .alert(.genericDeleteFailure("Sound font ID \(soundFontInfo.id) was not found."))
    }

    guard
      let kind = try? SoundFontKind(kind: soundFont.kind, location: soundFont.location, displayName: soundFontInfo.displayName)
    else {
      log.error("unexpected nil kind value for soundfont ID \(soundFontInfo.id)")
      return .alert(.genericDeleteFailure("Invalid (nil) sound font 'kind' value."))
    }

    guard !kind.isBuiltin else {
      log.error("unexpected kind value for soundfont ID \(soundFontInfo.id) - \(String(describing: kind), privacy: .public)")
      return .alert(.genericDeleteFailure("Cannot delete built-in sound fonts."))
    }

    var alert: Destination.State?
    if kind.deleteWhenRemoved {
      do {
        log.info("removing file \(kind.url)")
        try fileManager.removeItem(kind.url)
      } catch {
        log.error("failed to remove item \(kind.url) - \(error.localizedDescription, privacy: .public)")

        // Only alert user is the file still exists.
        if fileManager.fileExists(kind.url) {
          alert = .alert(.genericDeleteFailure("Failed to remove sound font file \(kind.url.lastPathComponent)."))
        }
      }
    }

    log.info("removing db entry for \(soundFont.displayName)")

    return alert
  }

  private func deleted(_ state: inout State, soundFontId: SoundFont.ID) -> Effect<Action> {
    if state.selectedPresetSource == .selected(soundFontId) {
      state.selectedPresetSource = nil
      return .send(.delegate(.presetSourceChanged(state.activePresetSource)))
    }

    if state.activePresetSource == .active(soundFontId) {
      state.activePresetSource = nil
      return .send(.delegate(.presetSourceChanged(state.activePresetSource)))
    }

    return .none
  }

  private func dismissSearch(_ state: inout State) -> Effect<Action> {
    state.rows = state.searchSource
    state.searchSource = []
    state.isSearchFieldPresented = false
    state.focusedField = nil
    state.lastSearchText = state.searchText
    state.searchText = ""
    return .none
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

    case .delete(let soundFontInfo):
      return confirmDeleteSoundFont(&state, soundFontInfo: soundFontInfo)

    case .edit(let soundFontInfo):
      return edit(&state, soundFontId: soundFontInfo.id)

    case .select(let soundFontInfo, let available):
      return selected(&state, soundFontId: soundFontInfo.id, available: available)
    }
  }

  private func monitorHideBuiltinFonts(_ state: inout State) -> Effect<Action> {
    .run { [$hideBuiltinFonts] send in
      for await _ in UncheckedSendable($hideBuiltinFonts.publisher.values.removeDuplicates()) {
        await send(.updateFetchAllQuery)
      }
    }.cancellable(id: CancelId.soundFontsListMonitorHideBuiltinFonts)
  }

  private func searchButtonTapped(_ state: inout State) -> Effect<Action> {
    state.searchSource = state.rows
    state.isSearchFieldPresented = true
    state.focusedField = .searchText
    state.searchText = ""
    state.rows = []
    return searchTextChanged(&state, searchText: state.lastSearchText ?? "")
  }

  private func searchTextChanged(_ state: inout State, searchText: String) -> Effect<Action> {
    if searchText != state.searchText {
      state.searchText = searchText
      state.rows = state.searchSource.filter {
        $0.soundFontInfo.displayName.localizedCaseInsensitiveContains(searchText.lowercased())
      }
    }
    return .none
  }

  private func selected(_ state: inout State, soundFontId: SoundFont.ID, available: Bool) -> Effect<Action> {
    if state.activePresetSource == .active(soundFontId) {
      if state.selectedPresetSource != nil {
        state.selectedPresetSource = nil
      }
      return .send(.delegate(.presetSourceChanged(available ? state.activePresetSource : nil)))
    } else if state.selectedPresetSource != .selected(soundFontId) {
      state.selectedPresetSource = .selected(soundFontId)
      return .send(.delegate(.presetSourceChanged(available ? state.selectedPresetSource : nil)))
    }
    return .none
  }

  private func selectedActivated(_ state: inout State) -> Effect<Action> {
    if let selectedPresetSource = state.selectedPresetSource {
      state.activePresetSource = selectedPresetSource.activated
      state.selectedPresetSource = nil
//      return .merge(
//        .send(.delegate(.presetSourceChanged(state.activePresetSource))),
//        showActiveSoundFont(&state)
//      )
    }
    return showActiveSoundFont(&state)
  }

  private func showActiveSoundFont(_ state: inout State) -> Effect<Action> {
    if let soundFontId = state.activePresetSource?.id,
       let index = state.rows.index(id: soundFontId) {
      return selected(&state, soundFontId: soundFontId, available: state.rows[index].statusInfoTag.available)
    }
    return .none
  }

  private func soundFontInfosChanged(_ state: inout State, soundFontInfos: [SoundFontInfo]) -> Effect<Action> {
    let update = IdentifiedArrayOf<SoundFontButton.State>(uncheckedUniqueElements: soundFontInfos.map { .init(soundFontInfo: $0) })
    if state.rows != update {
      state.rows = update
    }
    return .none
  }

  private func updateFetchAllQuery(_ tagId: Tag.ID) -> Effect<Action> {
    .run(priority: .utility, name: "monitorFetchAll") { send in
      @FetchAll var soundFontInfos: [SoundFontInfo]
      try await $soundFontInfos.load(SoundFontInfo.query(for: tagId))
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
  @FocusState private var focusedField: SoundFontsList.State.Field?
  private var searching: Bool { store.isSearchFieldPresented }

  public init(store: StoreOf<SoundFontsList>) {
    self.store = store
  }

  public var body: some View {
    VStack(spacing: 0) {
      if searching {
        searchField
      }
      StyledList {
        Section {
          ForEach(store.scope(state: \.rows, action: \.rows)) { rowStore in
            StyledEntry {
              SoundFontButtonView(
                store: rowStore,
                indicatorModifierState: indicatorModifierState(for: rowStore.id)
              )
            }
          }
        } header: {
          StyledHeader {
            sectionHeader
          }
        }
      }
    }
    .environment(\.editMode, $store.editingMode)
    .animation(.smooth, value: store.isSearchFieldPresented)
    .animation(.smooth, value: store.editingMode)
    .animation(.smooth, value: store.rows)
    .task { await store.send(.initialize).finish() }
    .alert($store.scope(state: \.destination?.alert, action: \.destination.alert))
  }

  private func indicatorModifierState(for soundFontId: SoundFont.ID) -> IndicatorModifier.State {
    store.activePresetSource == .active(soundFontId) ? .active :
    store.selectedPresetSource == .selected(soundFontId) ? .selected :
      .none
  }

  private var searchField: some View {
    HStack {
      TextField("Search", text: $store.searchText.sending(\.searchTextChanged))
        .textFieldStyle(.roundedBorder)
        .focused($focusedField, equals: .searchText)
#if os(iOS)
        .autocorrectionDisabled()
        .autocapitalization(.none)
#endif
        .transition(.slide)
        .bind($store.focusedField, to: $focusedField)
        .clearButton {
          store.send(.clearSearchTextField)
        }
      Spacer()
      Button {
        store.send(.cancelSearchButtonTapped)
      } label: {
        Image(systemName: "xmark")
          .frame(width: 32, height: 32)
          .contentShape(Rectangle())
      }
    }
    .padding(EdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 12))
  }

  private var sectionHeader: some View {
    ZStack(alignment: .leadingFirstTextBaseline) {
      HStack {
        Text("Files")
          .frame(maxWidth: .infinity, alignment: .leading)
          .contentShape(Rectangle())
          .onTapGesture(count: 2) {
            store.send(.headerDoubleTapped)
          }
        Spacer()
        Button {
          store.send(.searchButtonTapped)
        } label: {
          Image(systemName: "magnifyingglass")
            .imageScale(.small)
            .contentShape(Rectangle())
        }
      }
      .zIndex(1)
      .opacity((store.editingMode == .active || searching) ? 0.0 : 1.0)
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
      Text("Found \(store.rows.count)")
        .zIndex(3)
        .opacity(searching ? 1.0 : 0.0)
    }
  }
}

private let log: Logger = .init(category: "SoundFontsList")

#if DEBUG

extension SoundFontsListView {
  static var preview: some View {
    prepareDependencies {
      installApplicationFont()
      @Shared(.hideBuiltinFonts) var hideBuiltinFonts = false
      @Shared(.hideEmptyTags) var hideEmptyTags = false
      $0.defaultDatabase = previewDatabase()
    }

    // swiftlint:disable:next force_try
    let tag = try! Tag.make(displayName: "My Tag")
    Operations.tagSoundFont(tag.id, soundFontId: 2)

    return VStack {
      SoundFontsListView(store: Store(initialState: .init()) { SoundFontsList() })
      TagsListView(store: Store(initialState: .init(activeTagId: nil)) { TagsList() })
    }
  }
}

#Preview {
  SoundFontsListView.preview
    .environment(\.font, Font.body)
}

#endif // DEBUG
