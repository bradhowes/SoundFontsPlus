// Copyright © 2025 Brad Howes. All rights reserved.

import FeatureSupport
import SQLiteData
import Tags

/**
 Feature that manages a list of sound fonts, each entry of which is a `SoundFontButton` feature.

 The contents of the list comes from a `@FetchAll` query that operates on the active tag ID. When the tag changes, the query
 updates and ultimately so does the list.

 - Touching a button makes the associated sound font "selected" and the presets list will show the presets for the sound font.
 - Swiping right offers a button to edit the meta data associated with the font, including its display name.
 - Swiping left on user-installed fonts offers a button to delete the font.
 - Double-tapping on the "Files" header
 - Tap magnifying glass in "Files" header to search font display names
 */
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
    public var rows: IdentifiedArrayOf<SoundFontButton.State> = []
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
      let activeTagId = activeTagId ?? Tag.Ubiquitous.all.id
      self.activeTagId = activeTagId
      self.activePresetSource = activePresetSource
      self.selectedPresetSource = selectedPresetSource

      self.editingMode = editingMode

      self.searchSource = []
      self.searchText = ""
      self.isSearchFieldPresented = false

      let soundFontInfos: [SoundFontInfo] = withDatabaseReader { db in
        try SoundFontInfo.query(for: activeTagId).fetchAll(db)
      } ?? []

      Self.setRows(&self, soundFontInfos: soundFontInfos)
    }

    public static func setRows(_ state: inout Self, soundFontInfos: [SoundFontInfo]) {
      state.rows = .init(uniqueElements: soundFontInfos.map { .init(soundFontInfo: $0) })
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
    case fullStateChanged(Tag.ID, SoundFont.ID)
    case headerDoubleTapped
    case importFinished
    case initialize
    case missingSoundFontDetected(SoundFont.ID)
    case rows(IdentifiedActionOf<SoundFontButton>)
    case rowsSourceUpdated(source: [SoundFontInfo])
    case searchButtonTapped
    case searchTextChanged(String)
    case selectedIsNowActivated
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
        return updateFetchAllQuery(&state)

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

      case let .fullStateChanged(tagId, soundFontId):
        return fullStateChanged(&state, tagId: tagId, soundFontId: soundFontId)

      case .headerDoubleTapped:
        guard state.rows.first(where: { !$0.soundFontInfo.isBuiltin }) != nil else { return .none }
        state.editingMode = .active
        state.rows.forEach {
          state.rows[id: $0.id]?.deleting = false
        }
        return .none

      case .importFinished:
        return updateFetchAllQuery(&state)

      case .initialize:
        return initialize(&state)

      case .missingSoundFontDetected(let soundFontId):
        return missingSoundFontDetected(&state, soundFontId: soundFontId)

      case .rows(.element(_, .delegate(let action))):
        return processRowAction(&state, action: action)

      case .rowsSourceUpdated(source: let soundFontInfos):
        return rowsSourceUpdated(&state, source: soundFontInfos)

      case .searchButtonTapped:
        return searchButtonTapped(&state)

      case .searchTextChanged(let value):
        return searchTextChanged(&state, searchText: value)

      case .selectedIsNowActivated:
        return selectedIsNowActivated(&state)

      case .showActiveSoundFont:
        return showActiveSoundFont(&state)

      case .updateFetchAllQuery:
        return updateFetchAllQuery(&state)

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
    case soundFontsListMonitorFetchAllQueryOptions
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

  private func deleteSoundFontCollection(_ state: inout State, soundFontInfos: [SoundFontInfo]) -> Destination.State? {
    state.editingMode = .inactive
    var errors: [String] = []
    let ids = soundFontInfos.map { $0.id }

    @Dependency(\.defaultDatabase) var database
    do {
      try database.write { db in
        try SoundFont.delete()
          .where { ids.contains($0.id) }
          .execute(db)
      }
    } catch {
      errors.append("Failed to remove one or more sound font entries from the database - \(error.localizedDescription)")
    }

    state.rows.removeAll(where: { ids.contains($0.id) })

    for entry in soundFontInfos {
      // Should not happen if UI logic is correct.
      if !entry.isInstalled { continue }
      do {
        let url = try SoundFontKind(kind: entry.kind, location: entry.location, displayName: entry.displayName).url
        try fileManager.removeItem(url)
      } catch {
        errors.append("Failed to remove sound font '\(entry.displayName)' - \(error.localizedDescription)")
      }
    }

    guard !errors.isEmpty else { return nil }

    let msg = errors.reduce(into: "Failed to delete one or more sound fonts:\n") {
      $0.append("• " + $1 + "\n")
    }

    return .alert(.genericDeleteFailure(msg))
  }

  private func deleteSoundFontCollectionConfirmed(_ state: inout State, soundFontInfos: [SoundFontInfo]) -> Effect<Action> {
    state.destination = deleteSoundFontCollection(&state, soundFontInfos: soundFontInfos)
    return .merge(
      soundFontsDeleted(&state, soundFontIds: soundFontInfos.map(\.id)),
      showActiveSoundFont(&state)
    )
  }

  private func deleteSoundFont(_ state: inout State, soundFontInfo: SoundFontInfo) -> Destination.State? {
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

    withDatabaseWriter { db in
      try SoundFont.delete(soundFont)
        .execute(db)
    }

    log.info("removed db entry for \(soundFont.displayName)")

    state.rows.removeAll(where: { $0.id == soundFontInfo.id })

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

    return alert
  }

  private func deleteSoundFontConfirmed(_ state: inout State, soundFontInfo: SoundFontInfo) -> Effect<Action> {
    state.destination = deleteSoundFont(&state, soundFontInfo: soundFontInfo)
    return .merge(
      soundFontsDeleted(&state, soundFontIds: [soundFontInfo.id]),
      showActiveSoundFont(&state)
    )
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

  private func fullStateChanged(_ state: inout State, tagId: Tag.ID, soundFontId: SoundFont.ID) -> Effect<Action> {
    state.activePresetSource = .active(soundFontId)
    state.selectedPresetSource = nil
    state.activeTagId = tagId
    state.editingMode = .inactive
    state.isSearchFieldPresented = false
    return updateFetchAllQuery(&state)
  }

  private func initialize(_ state: inout State) -> Effect<Action> {
    .merge(
      monitorFetchAllQueryOptions(&state),
      updateFetchAllQuery(&state)
    )
  }

  private func missingSoundFontDetected(_ state: inout State, soundFontId: SoundFont.ID) -> Effect<Action> {
    SoundFont.delete(id: soundFontId)
    if state.activePresetSource == .active(soundFontId) {
      state.activePresetSource = nil
    }
    if state.selectedPresetSource == .selected(soundFontId) {
      state.selectedPresetSource = nil
    }
    return .none
  }

  private func monitorFetchAllQueryOptions(_ state: inout State) -> Effect<Action> {
    .run { [$hideBuiltinFonts] send in
      var stateMonitor = StateMonitor { $hideBuiltinFonts.wrappedValue }
      for await _ in $hideBuiltinFonts.publisher.values where stateMonitor.changed() {
        await send(.updateFetchAllQuery)
      }
    }.cancellable(id: CancelId.soundFontsListMonitorFetchAllQueryOptions)
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
      return soundFontSelected(&state, soundFontId: soundFontInfo.id, available: available)
    }
  }

  private func rowsSourceUpdated(_ state: inout State, source: [SoundFontInfo]) -> Effect<Action> {
    let update = IdentifiedArrayOf<SoundFontButton.State>(uncheckedUniqueElements: source.map { .init(soundFontInfo: $0) })
    if state.rows != update {
      state.rows = update
    }
    return .none
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

  private func selectedIsNowActivated(_ state: inout State) -> Effect<Action> {
    if let selectedPresetSource = state.selectedPresetSource {
      state.activePresetSource = selectedPresetSource.activated
      state.selectedPresetSource = nil
    }
    return showActiveSoundFont(&state)
  }

  private func showActiveSoundFont(_ state: inout State) -> Effect<Action> {
    if let soundFontId = state.activePresetSource?.id,
       let index = state.rows.index(id: soundFontId) {
      return soundFontSelected(&state, soundFontId: soundFontId, available: state.rows[index].statusInfoTag.available)
    }
    return .none
  }

  private func soundFontsDeleted(_ state: inout State, soundFontIds: [SoundFont.ID]) -> Effect<Action> {
    for soundFontId in soundFontIds {
      if state.selectedPresetSource == .selected(soundFontId) {
        state.selectedPresetSource = nil
        return .send(.delegate(.presetSourceChanged(state.activePresetSource)))
      }

      if state.activePresetSource == .active(soundFontId) {
        state.activePresetSource = nil
        return .send(.delegate(.presetSourceChanged(state.activePresetSource)))
      }
    }

    return .none
  }

  private func soundFontSelected(_ state: inout State, soundFontId: SoundFont.ID, available: Bool) -> Effect<Action> {
    log.info("soundFontSelected BEGIN")
    if state.activePresetSource == .active(soundFontId) {
      if state.selectedPresetSource != nil {
        state.selectedPresetSource = nil
      }
      log.info("soundFontSelected END - is active preset source")
      return .send(.delegate(.presetSourceChanged(available ? state.activePresetSource : nil)))
    } else if state.selectedPresetSource != .selected(soundFontId) {
      state.selectedPresetSource = .selected(soundFontId)
      log.info("soundFontSelected END - is selected preset source")
      return .send(.delegate(.presetSourceChanged(available ? state.selectedPresetSource : nil)))
    }
    log.info("soundFontSelected END - .none")
    return .none
  }

  private func updateFetchAllQuery(_ state: inout State) -> Effect<Action> {
    .run(priority: .utility, name: "soundFontsListUpdateFetchAllQuery") { [tagId = state.activeTagId] send in
      @FetchAll var soundFontInfos: [SoundFontInfo]
      try await $soundFontInfos.load(SoundFontInfo.query(for: tagId))
      for try await source in $soundFontInfos.publisher.values.removeDuplicates() {
        await send(.rowsSourceUpdated(source: source))
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
            Image(systemName: .cancelButtonImageName)
              .frame(width: 32, height: 32)
              .contentShape(Rectangle())
          }
        }
        .padding(EdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 12))
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
                  Image(systemName: .searchButtonImageName)
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
      }
    }
    .helpInfoViewTag(.fontsList)
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
}

private let log: Logger = .init(category: "SoundFontsList")

#if DEBUG

extension SoundFontsListView {

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
      SoundFontsListView(store: Store(initialState: .init()) { SoundFontsList() })
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
//    $0.defaultDatabase = previewDatabase { db in
//      let mine = try SoundFont.add(
//        db: db,
//        displayName: "Mine",
//        soundFontKind: .installed(filename: SF2Resource.resources[2].absoluteString)
//      )
//
//      if let tag = try? Tag.make(displayName: "My Tag") {
//        SoundFont.link(soundFontId: mine.id, to: tag.id)
//      }
//    }
  }

  @Shared(.hideBuiltinFonts) var hideBuiltinFonts = false
  @Shared(.hideEmptyTags) var hideEmptyTags = false

  SoundFontsListView.preview
    .environment(\.font, Font.body)
}

#endif // DEBUG
