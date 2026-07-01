// Copyright © 2025 Brad Howes. All rights reserved.

import Algorithms // for `chunks` addition to collections
import FeatureSupport
import Sharing
import SQLiteData

/**
 List of presets for the selected soundfont. Contains a collection of `PresetsListSection` entities that group
 presets into bundles of N presets.
 */
@Reducer
public struct PresetsList {
  public static var groupingSize: Int { 20 } // New section ever 20 presets
  public static var searchGroupingSize: Int { 10_000 } // When searching, just one very large group
  public static var delayBeforeShowingActivePreset: Duration { .milliseconds(500) }

  @Reducer
  public enum Destination {
    case alert(AlertState<Alert>)

    @CasePathable
    public enum Alert: Equatable {
      case deleteFavoriteConfirmed(Preset)
      case hidePresetConfirmed(Preset)
      case missingFileForSelectedPreset(SoundFont.ID)
    }
  }

  public enum ScrollToTarget: Equatable {
    case preset(Preset.ID)
    case section(String)
  }

  @ObservableState
  public struct State: Equatable {
    @Presents public var destination: Destination.State?
    public var presets: [Preset]
    public var sections: IdentifiedArrayOf<PresetsListSection.State> = .init()
    public var searchText: String
    public var isSearchFieldPresented: Bool
    public var focusedField: Field?
    public var optionalSearchText: String? { isSearchFieldPresented ? searchText : nil }
    public var scrollToTarget: ScrollToTarget?
    public var presetSource: PresetSource?
    public var activePresetId: Preset.ID?
    public var activePresetIndex: Int? {
      guard let activePresetId else { return nil }
      return presets.first(where: { $0.id == activePresetId })?.index
    }

    public enum Field: String, Hashable {
      case searchText
    }

    public var editingVisibility: Bool

    public init(
      presetSource: PresetSource? = nil,
      activePresetId: Preset.ID? = nil,
      destination: Destination.State? = nil,
      sections: IdentifiedArrayOf<PresetsListSection.State> = [],
      searchText: String? = nil,
      focusedField: Field? = nil,
      editingVisibility: Bool = false
    ) {
      self.presetSource = presetSource
      self.activePresetId = activePresetId
      self.isSearchFieldPresented = searchText != nil
      self.searchText = searchText ?? ""
      self.editingVisibility = editingVisibility

      if let soundFontId = presetSource?.id {
        self.presets = editingVisibility ? Preset.all(for: soundFontId) : Preset.visible(for: soundFontId)
      } else {
        self.presets = []
      }

      self.sections = group(presets, searching: searchText != nil)
    }
  }

  public enum Action: BindableAction, Equatable {
    case activePresetChanged(presetId: Preset.ID, info: PresetLoadingInfo)
    case binding(BindingAction<State>)
    case cancelSearchButtonTapped
    case clearScrollToTarget
    case clearSearchTextField
    case deinitialize
    case delegate(Delegate)
    case destination(PresentationAction<Destination.Action>)
    case editingVisibilityChanged(Bool)
    case initialize
    case presetSourceChanged(PresetSource?)
    case rowsSourceUpdated(source: [Preset], showActive: Bool)
    case searchTextChanged(String)
    case sections(IdentifiedActionOf<PresetsListSection>)
    case sectionHeaderIndexTapped(String)
    case showPresetDelayed(Preset.ID)
    case showPresetNow(Preset.ID)
    case updateFetchAllQuery

    @CasePathable
    public enum Delegate: Equatable {
      case activePresetIdChanged(Preset.ID?)
      case edit(sectionId: PresetsListSection.State.ID, preset: Preset)
      case missingSoundFontDetected(SoundFont.ID)
    }
  }

  public init() {}

  @Dependency(\.continuousClock) var clock
  @Dependency(\.fileManager) var fileManager
  @Shared(.favoritesOnTop) public var favoritesOnTop
  @Shared(.showOnlyFavorites) public var showOnlyFavorites
  @Shared(.sortPresetsByName) public var sortPresetsByName
  @Shared(.starFavoriteNames) public var starFavoriteNames

  public var body: some ReducerOf<Self> {
    BindingReducer()
    Reduce<State, Action> { state, action in
      log.action("PresetsList", action)
      switch action {

        // From AUv3Root
      case let .activePresetChanged(presetId: presetId, info: presetLoadingInfo):
        return activePresetChanged(&state, presetId: presetId, info: presetLoadingInfo)

      case .cancelSearchButtonTapped:
        return dismissSearch(&state)

      case .clearSearchTextField:
        return searchTextChanged(&state, searchText: "")

      case .clearScrollToTarget:
        state.scrollToTarget = nil
        return .none

      case .deinitialize:
        return .merge(CancelId.allCases.map { .cancel(id: $0) })

      case .destination(.presented(.alert(.deleteFavoriteConfirmed(let preset)))):
        return deleteFavoriteConfirmed(&state, preset: preset)

      case .destination(.presented(.alert(.hidePresetConfirmed(let preset)))):
        return hidePresetConfirmed(&state, preset: preset)

      case .destination(.presented(.alert(.missingFileForSelectedPreset(let soundFontId)))):
        return .send(.delegate(.missingSoundFontDetected(soundFontId)))

      case let .editingVisibilityChanged(editing):
        state.editingVisibility = editing
        return updateFetchAllQuery(&state, showActive: false)

      case .initialize:
        return initialize(&state)

      case .presetSourceChanged(let presetSource):
        return presetSourceChanged(&state, presetSource: presetSource)

      case let .rowsSourceUpdated(source: presets, showActive: showActive):
        state.presets = presets
        if showActive, let activePresetId = state.activePresetId {
          state.scrollToTarget = .preset(activePresetId)
        }
        return generatePresetSections(&state)

      case .searchTextChanged(let value):
        return searchTextChanged(&state, searchText: value)

      case let .sections(.element(id: sectionId, action: .delegate(action))):
        return processSectionAction(&state, sectionId: sectionId, action: action)

      case .sectionHeaderIndexTapped(let title):
        return sectionHeaderIndexTapped(&state, title: title)

      case .showPresetDelayed(let presetId):
        return showPresetDelayed(&state, presetId: presetId)

      case .showPresetNow(let presetId):
        state.scrollToTarget = .preset(presetId)
        return .none

      case .updateFetchAllQuery:
        return updateFetchAllQuery(&state, showActive: false)

      default:
        return .none
      }
    }
    .forEach(\.sections, action: \.sections) {
      PresetsListSection()
    }
    .ifLet(\.destination, action: \.destination)
  }

  private enum CancelId: String, CaseIterable {
    case presetsListMonitorFetchAllQueryOptions
    case presetsListShowPresetNow
    case presetsListUpdateFetchAll
  }
}

extension PresetsList {

  private func activePresetChanged(_ state: inout State, presetId: Preset.ID, info: PresetLoadingInfo) -> Effect<Action> {
    guard
      let kind = try? SoundFontKind(kind: info.kind, location: info.location, displayName: info.soundFontName),
      kind.url.withSecurityScoping({ fileManager.fileExists($0) }) == true
    else {
      state.destination = .alert(
        .missingFileForSelectedPreset(
          action: .missingFileForSelectedPreset(info.soundFontId),
          displayName: info.soundFontName
        )
      )
      return .none
    }

    if state.activePresetId != presetId {
      state.presetSource = state.presetSource?.activated
      state.activePresetId = presetId
      return .merge(
        generatePresetSections(&state),
        .send(.delegate(.activePresetIdChanged(presetId)))
      )
    }
    return .none
  }

  private func deleteFavoriteConfirmed(_ state: inout State, preset: Preset) -> Effect<Action> {
    precondition(preset.isFavorite)
    withDatabaseWriter { db in
      try Preset.delete(preset)
        .execute(db)
    }

    if preset.id == state.activePresetId {
      return .send(.delegate(.activePresetIdChanged(nil)))
    }
    return .none
  }

  private func dismissSearch(_ state: inout State) -> Effect<Action> {
    state.isSearchFieldPresented = false
    state.focusedField = nil
    state.scrollToTarget = nil
    return .merge(
      generatePresetSections(&state),
      showPresetDelayed(&state, presetId: state.activePresetId ?? state.presets[0].id)
    )
  }

  @discardableResult
  private func generatePresetSections(_ state: inout State) -> Effect<Action> {
    log.debug("generatePresetSections BEGIN")
    state.sections = group(
      {
        if let searchText = state.optionalSearchText {
          state.presets.filter {
            $0.displayName.localizedCaseInsensitiveContains(searchText)
          }
        } else {
          state.presets
        }
      }(),
      searching: state.isSearchFieldPresented
    )

    log.debug("generatePresetSections END")
    return .none
  }

  private func hidePreset(_ state: inout State, preset: Preset) -> Effect<Action> {
    @Shared(.confirmPresetHiding) var confirmPresetHiding
    if confirmPresetHiding {
      state.destination = .alert(
        .confirmHidePreset(action: .hidePresetConfirmed(preset), displayName: preset.displayName)
      )
      return .none
    }
    return hidePresetConfirmed(&state, preset: preset)
  }

  private func hidePresetConfirmed(_ state: inout State, preset: Preset) -> Effect<Action> {
    precondition(!preset.isFavorite)
    @Shared(.confirmPresetHiding) var confirmPresetHiding
    $confirmPresetHiding.withLock { $0 = false }
    var preset = preset
    preset.toggleVisibility()
    return .none
  }

  private func initialize(_ state: inout State) -> Effect<Action> {
    .merge(
      monitorFetchAllQueryOptions(&state),
      updateFetchAllQuery(&state, showActive: false)
    )
  }

  private func monitorFetchAllQueryOptions(_ state: inout State) -> Effect<Action> {
    .run { [$favoritesOnTop, $showOnlyFavorites, $starFavoriteNames, $sortPresetsByName] send in
      var stateMonitor = StateMonitor {
        [
          $favoritesOnTop.wrappedValue,
          $showOnlyFavorites.wrappedValue,
          $starFavoriteNames.wrappedValue,
          $sortPresetsByName.wrappedValue
        ]
      }

      for await _ in $favoritesOnTop.publisher
        .merge(with: $showOnlyFavorites.publisher, $starFavoriteNames.publisher, $sortPresetsByName.publisher)
        .values where stateMonitor.changed() {
        await send(.updateFetchAllQuery)
      }
    }.cancellable(id: CancelId.presetsListMonitorFetchAllQueryOptions, cancelInFlight: true)
  }

  private func presetSourceChanged(_ state: inout State, presetSource: PresetSource?) -> Effect<Action> {
    guard state.presetSource != presetSource else { return .none }
    state.presetSource = presetSource
    return updateFetchAllQuery(&state, showActive: true)
  }

  private func processSectionAction(
    _ state: inout State,
    sectionId: PresetsListSection.State.ID,
    action: PresetsListSection.Action.Delegate
  ) -> Effect<Action> {
    switch action {

    case .createFavoriteTapped(let preset):
      if let favorite = preset.clone() {
        return .send(.showPresetDelayed(favorite.id))
      }
      return .none

    case .deleteFavoriteTapped(let preset):
      state.destination = .alert(
        .confirmDeleteFavorite(action: .deleteFavoriteConfirmed(preset), displayName: preset.displayName)
      )
      return .none

    case .editPresetTapped(let preset):
      return .send(.delegate(.edit(sectionId: sectionId, preset: preset)))

    case let .headerTapped(sectionId, count):
      return sectionHeaderTapped(&state, sectionId: sectionId, count: count)

    case .hidePresetTapped(let preset):
      return hidePreset(&state, preset: preset)

    case .searchButtonTapped:
      return searchButtonTapped(&state)

    case .presetButtonTapped(let preset):
      return selectPreset(&state, preset: preset)
    }
  }

  private func searchButtonTapped(_ state: inout State) -> Effect<Action> {
    state.isSearchFieldPresented = true
    state.focusedField = .searchText
    state.scrollToTarget = nil
    return generatePresetSections(&state)
  }

  private func searchTextChanged(_ state: inout State, searchText: String) -> Effect<Action> {
    if searchText != state.searchText {
      state.searchText = searchText
      return generatePresetSections(&state)
    }
    return .none
  }

  private func sectionHeaderIndexTapped(_ state: inout State, title: String) -> Effect<Action> {
    log.info("sectionHeaderIndexTapped BEGIN - title: \(title)")
    if let index = state.sections.firstIndex(where: { $0.sectionIndex == title }) {
      log.info("sectionHeaderIndexTapped section index: \(index)")
      state.scrollToTarget = .section(title)
    }
    return .none
  }

  private func sectionHeaderTapped(_ state: inout State, sectionId: PresetsListSection.State.ID, count: Int) -> Effect<Action> {
    log.info("sectionHeaderTapped BEGIN - sectionId: \(sectionId), count: \(count)")
    if count == 2 {
      state.scrollToTarget = .preset(state.presets[0].id)
    } else if count == 1 {
      let index = sectionId.rawValue
      if index > 0 {
        let previous = index - 1
        state.scrollToTarget = .preset(state.sections[previous].rows[0].preset.id)
      }
    }
    return .none
  }

  private func selectPreset(_ state: inout State, preset: Preset) -> Effect<Action> {
    guard let info = PresetLoadingInfo.for(id: preset.id) else { return .none }
    guard
      let kind = try? SoundFontKind(kind: info.kind, location: info.location, displayName: info.soundFontName),
      kind.url.withSecurityScoping({ fileManager.fileExists($0) }) == true
    else {
      state.destination = .alert(
        .missingFileForSelectedPreset(
          action: .missingFileForSelectedPreset(info.soundFontId),
          displayName: info.soundFontName
        )
      )
      return .none
    }

    if state.activePresetId != preset.id {
      state.presetSource = state.presetSource?.activated
      state.activePresetId = preset.id
      return .merge(
        generatePresetSections(&state),
        .send(.delegate(.activePresetIdChanged(preset.id)))
      )
    }
    return .none
  }

  private func showPresetDelayed(_ state: inout State, presetId: Preset.ID) -> Effect<Action> {
    log.info("showPreset BEGIN - presetId: \(presetId)")
    return .run { [clock] send in
      try await clock.sleep(for: Self.delayBeforeShowingActivePreset)
      if !Task.isCancelled {
        await send(.showPresetNow(presetId))
      }
    }.cancellable(id: CancelId.presetsListShowPresetNow, cancelInFlight: true)
  }

  private func updateFetchAllQuery(_ state: inout State, showActive: Bool) -> Effect<Action> {
    log.info("updateFetchAllQuery")
    let soundFontId = state.presetSource?.id ?? -1
    let query = state.editingVisibility ? Preset.allQuery(for: soundFontId) : Preset.visibleQuery(for: soundFontId)

    return .run(priority: .utility, name: "presetsListUpdateFetchAllQuery") { [showActive] send in
      log.info("updateFetchAllQuery - begin task")
      defer { log.info("updateFetchQuery END")}
      var showActive = showActive
      @FetchAll var presets: [Preset]
      try await $presets.load(query, animation: .smooth)
      log.info("updateFetchAllQuery - updated query")
      if Task.isCancelled { return }
      for try await source in $presets.publisher.values.removeDuplicates() {
        log.info("updateFetchAllQuery - query changed")
        if Task.isCancelled { break }
        await send(.rowsSourceUpdated(source: source, showActive: showActive))
        showActive = false
      }
    }.cancellable(id: CancelId.presetsListUpdateFetchAll, cancelInFlight: true)
  }
}

extension PresetsList.Destination.Action: Equatable {}
extension PresetsList.Destination.State: Equatable {}
extension PresetsList.Destination.State: _EphemeralState { public typealias Action = Alert }

// MARK: - View

public struct PresetsListView: View {
  @Bindable private var store: StoreOf<PresetsList>
  @FocusState private var focusedField: PresetsList.State.Field?
  @GestureState private var dragLocation: CGPoint = .zero
  @Shared(.showPresetIndexView) private var showPresetIndexView

  public init(store: StoreOf<PresetsList>) {
    self.store = store
  }

  public var body: some View {
    VStack(spacing: 0) {
      if store.isSearchFieldPresented {
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
      ScrollViewReader { proxy in
        StyledList {
          ForEach(store.scope(state: \.sections, action: \.sections)) { rowStore in
            PresetsListSectionView(
              store: rowStore,
              searching: store.isSearchFieldPresented,
              activePresetId: store.activePresetId,
              presetSource: store.presetSource
            )
          }
        }
        .helpInfoViewTag(.presetsList)
        .overlay(alignment: .trailing) {
          if showPresetIndexView {
            VStack {
              ViewThatFits(in: [.vertical]) {
                ForEach(1...4, id: \.self) { stride in
                  VStack(spacing: 0) {
                    if store.sections.count > 2 {
                      ForEach(store.sections.map(\.sectionIndex).striding(by: stride), id: \.self) { title in
                        SectionIndexTitleView(title: title)
                          .font(.caption)
                          .foregroundStyle(Color.gray)
                          .padding([.leading, .trailing], 8)
                          .containerShape(Rectangle())
                          .clipShape(.rect)
                          .background(dragObserver(title: title))
                      }
                    }
                  }
                  .gesture(
                    DragGesture(minimumDistance: 0, coordinateSpace: .global)
                      .updating($dragLocation) { value, state, _ in
                        state = value.location
                      }
                  )
                  .padding([.top, .bottom], 8)
                  .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerSize: .init(width: 12, height: 12), style: .continuous))
                  .frame(maxWidth: .infinity, alignment: .trailing)
                }
              }
            }
          }
        }
        .onChange(of: store.scrollToTarget) {
          doScrollTo(proxy: proxy)
        }
      }
    }
    .environment(
      \.editMode,
       Binding(
        get: { store.editingVisibility ? EditMode.active : .inactive },
        set: { store.send(.editingVisibilityChanged($0 == .active)) }
       )
    )
    .animation(.smooth, value: store.isSearchFieldPresented)
    .animation(.smooth, value: store.editingVisibility)
    .animation(.smooth, value: store.presets)
    .task { await store.send(.initialize).finish() }
    .alert($store.scope(state: \.destination?.alert, action: \.destination.alert))
  }

  private func dragObserver(title: String) -> some View {
    GeometryReader { geometry in
      dragObserver(geometry: geometry, title: title)
    }
  }

  private func dragObserver(geometry: GeometryProxy, title: String) -> some View {
    if geometry.frame(in: .global).contains(dragLocation) {
      DispatchQueue.main.async {
        store.send(.sectionHeaderIndexTapped(title))
      }
    }
    return Rectangle().fill(Color.clear)
  }

  private func doScrollTo(proxy: ScrollViewProxy) {
    if let value = store.scrollToTarget {
      switch value {
      case .preset(let presetId):
        withAnimation {
          proxy.scrollTo(presetId)
        }

      case .section(let sectionId):
        withAnimation {
          proxy.scrollTo(sectionId, anchor: .top)
        }
      }
      store.send(.clearScrollToTarget)
    }
  }
}

struct SectionIndexTitleView: View {
  private let title: String

  init(title: String) {
    self.title = title
  }

  var body: some View {
    if title == "!" {
      Image(systemName: .favoriteButtonImageName)
    } else {
      Text(title)
    }
  }
}

private let log: Logger = .init(category: "PresetsList")

#if DEBUG

extension PresetsListView {

  static var preview: some View {
    let soundFontId: SoundFont.ID = 1
    return VStack {
      let store = Store(initialState: .init(presetSource: .active(soundFontId))) { PresetsList() }
      PresetsListView(store: store)
      Toggle(
        "Editing",
        isOn: Binding(
          get: { store.editingVisibility },
          set: { store.send(.editingVisibilityChanged($0)) }
        )
      )
    }
  }

  static var previewEditing: some View {
    PresetsListView(store: Store(initialState: .init(presetSource: .active(SoundFont.ID(1)), editingVisibility: true)) {
      PresetsList()
    })
  }
}

#Preview {
  // swiftlint:disable:next redundant_discardable_let
  let _ = prepareDependencies {
    installApplicationFont()
    $0.defaultDatabase = previewDatabase()
  }
  PresetsListView.preview
}

#endif // DEBUG
