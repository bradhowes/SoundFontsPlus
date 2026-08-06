// Copyright © 2025 Brad Howes. All rights reserved.

import Algorithms // for `chunks` addition to collections
import AsyncAlgorithms
public import CasePaths
import Combine
public import ComposableArchitecture
import FeatureSupport
public import Models
import Sharing
import SQLiteData
public import SwiftUI
public import Tagged

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
      case deleteFavoriteConfirmed(Preset.ID)
      case hidePresetConfirmed(Preset.ID)
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
    public var presets: [PresetInfo]
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
        self.presets = editingVisibility ? PresetInfo.all(for: soundFontId) : PresetInfo.visible(for: soundFontId)
      } else {
        self.presets = []
      }

      self.sections = group(presets, searching: searchText != nil)
    }
  }

  public enum Action: BindableAction, Equatable {
    case binding(BindingAction<State>)
    case cancelSearchButtonTapped
    case clearScrollToTarget
    case clearSearchTextField
    case deinitialize
    case delegate(Delegate)
    case destination(PresentationAction<Destination.Action>)
    case editingVisibilityChanged(Bool)
    case fullStateChanged(SoundFont.ID, Preset.ID)
    case initialize
    case presetSourceChanged(PresetSource?)
    case rowsSourceUpdated(source: [PresetInfo], showActive: Bool)
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
      return switch action {
      case .binding: .none
      case .cancelSearchButtonTapped: dismissSearch(&state)
      case .clearSearchTextField: searchTextChanged(&state, searchText: "")
      case .clearScrollToTarget: clearScrollToTarget(&state)
      case .deinitialize: .merge(CancelId.allCases.map { .cancel(id: $0) })
      case .delegate: .none
      case .destination(.dismiss): .none
      case .destination(.presented(.alert(.deleteFavoriteConfirmed(let presetId)))):
        deleteFavoriteConfirmed(&state, presetId: presetId)
      case .destination(.presented(.alert(.hidePresetConfirmed(let presetId)))): hidePresetConfirmed(&state, presetId: presetId)
      case .destination(.presented(.alert(.missingFileForSelectedPreset(let soundFontId)))):
        .send(.delegate(.missingSoundFontDetected(soundFontId)))
      case .editingVisibilityChanged(let editing): editingVisibilityChanged(&state, editing: editing)
      case let .fullStateChanged(soundFontId, presetId): fullStateChanged(&state, soundFontId: soundFontId, presetId: presetId)
      case .initialize: initialize(&state)
      case .presetSourceChanged(let presetSource): presetSourceChanged(&state, presetSource: presetSource)
      case let .rowsSourceUpdated(source: presets, showActive: showActive):
        rowsSourceUpdated(&state, presets: presets, showActive: showActive)
      case .searchTextChanged(let value): searchTextChanged(&state, searchText: value)
      case let .sections(.element(id: sectionId, action: .delegate(action))):
        processSectionAction(&state, sectionId: sectionId, action: action)
      case .sections(.element(id: _, action: .rows)): .none
      case .sectionHeaderIndexTapped(let title): sectionHeaderIndexTapped(&state, title: title)
      case .showPresetDelayed(let presetId): showPresetDelayed(&state, presetId: presetId)
      case .showPresetNow(let presetId): showPresetNow(&state, presetId: presetId)
      case .updateFetchAllQuery: updateFetchAllQuery(&state, showActive: false)
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
    case presetsListUpdateFetchAllQuery
  }
}

extension PresetsList {

  private func clearScrollToTarget(_ state: inout State) -> Effect<Action> {
    state.scrollToTarget = nil
    return .none
  }

  private func deleteFavoriteConfirmed(_ state: inout State, presetId: Preset.ID) -> Effect<Action> {
    guard let preset = Preset.with(id: presetId) else { return .none }
    precondition(preset.isFavorite)
    withDatabaseWriter { db in
      try Preset.delete(preset)
        .execute(db)
    }

    if presetId == state.activePresetId {
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

  private func editingVisibilityChanged(_ state: inout State, editing: Bool) -> Effect<Action> {
    state.editingVisibility = editing
    return updateFetchAllQuery(&state, showActive: false)
  }

  private func fullStateChanged(_ state: inout State, soundFontId: SoundFont.ID, presetId: Preset.ID) -> Effect<Action> {
    log.info("fullStateChanged BEGIN")
    state.presetSource = .active(soundFontId)
    state.activePresetId = presetId
    state.isSearchFieldPresented = false
    state.editingVisibility = false
    log.info("fullStateChanged END")
    return .none
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

  private func hidePresetTapped(_ state: inout State, preset: Preset) -> Effect<Action> {
    @Shared(.confirmPresetHiding) var confirmPresetHiding
    if confirmPresetHiding {
      state.destination = .alert(
        .confirmHidePreset(action: .hidePresetConfirmed(preset.id), displayName: preset.displayName)
      )
      return .none
    }
    return hidePresetConfirmed(&state, presetId: preset.id)
  }

  private func hidePresetConfirmed(_ state: inout State, presetId: Preset.ID) -> Effect<Action> {
    @Shared(.confirmPresetHiding) var confirmPresetHiding
    $confirmPresetHiding.withLock { $0 = false }
    if var preset = Preset.with(id: presetId) {
      preset.toggleVisibility()
    }
    return .none
  }

  private func initialize(_ state: inout State) -> Effect<Action> {
    .merge(
      monitorFetchAllQueryOptions(&state),
      updateFetchAllQuery(&state, showActive: false)
    )
  }

  private func monitorFetchAllQueryOptions(_ state: inout State) -> Effect<Action> {
    log.info("monitorFetchAllQueryOptions BEGIN")
    return .run { [$favoritesOnTop, $showOnlyFavorites, $starFavoriteNames, $sortPresetsByName] send in
      defer { log.info("monitorFetchAllQueryOptions END - task cancelled") }
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
        log.info("monitorFetchAllQueryOptions - state changed")
        await send(.updateFetchAllQuery)
      }
    }.cancellable(id: CancelId.presetsListMonitorFetchAllQueryOptions, cancelInFlight: true)
  }

  private func presetButtonTapped(_ state: inout State, preset: Preset) -> Effect<Action> {
    log.info("presetButtonTapped BEGIN - preset: \(preset.displayName)")
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

    log.info("presetButtonTapped END")
    return .none
  }

  private func presetSourceChanged(_ state: inout State, presetSource: PresetSource?) -> Effect<Action> {
    log.info("presetSourceChanged BEGIN")
    guard state.presetSource != presetSource else {
      if let presetId = state.activePresetId {
        state.scrollToTarget = .preset(presetId)
      }
      return .none
    }
    state.presetSource = presetSource
    log.info("presetSourceChanged END")
    return updateFetchAllQuery(&state, showActive: true)
  }

  private func processSectionAction(
    _ state: inout State,
    sectionId: PresetsListSection.State.ID,
    action: PresetsListSection.Action.Delegate
  ) -> Effect<Action> {

    func withPreset(_ presetId: Preset.ID, closure: (inout State, Preset) -> Effect<Action>) -> Effect<Action> {
      if let preset = Preset.with(id: presetId) {
        return closure(&state, preset)
      }
      return .none
    }

    switch action {

    case .createFavoriteTapped(let presetId):
      return withPreset(presetId) { _, preset in
        if let favorite = preset.cloneFavorite() {
          return .send(.showPresetDelayed(favorite.id))
        }
        return .none
      }

    case .deleteFavoriteTapped(let presetId):
      return withPreset(presetId) { state, preset in
        state.destination = .alert(
          .confirmDeleteFavorite(action: .deleteFavoriteConfirmed(preset.id), displayName: preset.displayName)
        )
        return .none
      }

    case .editPresetTapped(let presetId):
      return withPreset(presetId) { _, preset in
        .send(.delegate(.edit(sectionId: sectionId, preset: preset)))
      }

    case let .headerTapped(sectionId, count):
      return sectionHeaderTapped(&state, sectionId: sectionId, count: count)

    case .hidePresetTapped(let presetId):
      return withPreset(presetId) { state, preset in
        hidePresetTapped(&state, preset: preset)
      }

    case .searchButtonTapped:
      return searchButtonTapped(&state)

    case .presetButtonTapped(let presetId):
      return withPreset(presetId) { state, preset in
        presetButtonTapped(&state, preset: preset)
      }
    }
  }

  private func rowsSourceUpdated(_ state: inout State, presets: [PresetInfo], showActive: Bool) -> Effect<Action> {
    log.info("rowsSourceUpdated BEGIN - presets.count: \(presets.count, privacy: .public) showActive: \(showActive, privacy: .public)")
    state.presets = presets
    if showActive, let activePresetId = state.activePresetId {
      state.scrollToTarget = .preset(activePresetId)
    }
    log.info("rowsSourceUpdated END")
    return generatePresetSections(&state)
  }

  private func searchButtonTapped(_ state: inout State) -> Effect<Action> {
    log.info("searchButtonTapped BEGIN")
    state.isSearchFieldPresented = true
    state.focusedField = .searchText
    state.scrollToTarget = nil
    log.info("searchButtonTapped END")
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
    if let index = state.sections.firstIndex(where: { $0.indexKey == title }) {
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
      let index = sectionId
      if index > 0 {
        let previous = index - 1
        state.scrollToTarget = .preset(state.sections[previous].rows[0].id)
      }
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

  private func showPresetNow(_ state: inout State, presetId: Preset.ID) -> Effect<Action> {
    state.scrollToTarget = .preset(presetId)
    return .none
  }

  private func updateFetchAllQuery(_ state: inout State, showActive: Bool) -> Effect<Action> {
    log.info("updateFetchAllQuery BEGIN")
    let soundFontId = state.presetSource?.id ?? -1
    let query = state.editingVisibility ? PresetInfo.allQuery(for: soundFontId) : PresetInfo.visibleQuery(for: soundFontId)

    return .run(priority: .utility, name: CancelId.presetsListUpdateFetchAllQuery.rawValue) { [showActive] send in
      log.info("updateFetchAllQuery - begin task")
      defer { log.info("updateFetchQuery END - task cancelled") }
      var showActive = showActive

      // Update the query and then monitor for value changes
      @FetchAll var presets: [PresetInfo]
      try await $presets.load(query, animation: .smooth)
      log.info("updateFetchAllQuery - updated query")
      if Task.isCancelled { return }

      for try await source in $presets.publisher.values.removeDuplicates() {
        if Task.isCancelled { break }
        log.info("updateFetchAllQuery - detected change showActive: \(showActive)")
        await send(.rowsSourceUpdated(source: source, showActive: showActive))
        showActive = false
      }
      log.info("updateFetchAllQuery END - source iteration terminated")
    }.cancellable(id: CancelId.presetsListUpdateFetchAllQuery, cancelInFlight: true)
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
                      ForEach(store.sections.map(\.indexKey).striding(by: stride), id: \.self) { title in
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
                  .background(
                    Color.white.opacity(0.1),
                    in: RoundedRectangle(cornerSize: .init(width: 12, height: 12), style: .continuous)
                  )
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
