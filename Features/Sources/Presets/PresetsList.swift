// Copyright © 2025 Brad Howes. All rights reserved.

import Algorithms // for `chunks` addition to collections
import FeatureSupport

/**
 List of presets for the selected soundfont. Contains a collection of `PresetsListSection` entities that group
 presets into bundles of N presets.
 */
@Reducer
public struct PresetsList {
  public static var groupingSize: Int { 20 }
  public static var noGroupingSize: Int { 10_000 }
  public static var delayBeforeShowingActivePreset: Duration { .milliseconds(100) }
  public static var playNoteDuration: Duration { .milliseconds(250) }

  @Reducer
  public enum Destination {
    case alert(AlertState<Alert>)

    @CasePathable
    public enum Alert: Equatable {
      case deleteFavoriteConfirmed(Preset)
      case hidePresetConfirmed(Preset)
    }
  }

  public struct ScrollToTarget: Equatable {
    public let presetId: Preset.ID
    public let anchor: UnitPoint

    public init?(presetId: Preset.ID?, anchor: UnitPoint = .center) {
      guard let presetId = presetId else { return nil }
      self.presetId = presetId
      self.anchor = anchor
    }
  }

  // MARK: -
  @ObservableState
  public struct State: Equatable {
    @Presents public var destination: Destination.State?
    public var sections: IdentifiedArrayOf<PresetsListSection.State>
    public var searchText: String
    public var isSearchFieldPresented: Bool
    public var focusedField: Field?
    public var optionalSearchText: String? { isSearchFieldPresented ? searchText : nil }
    public var scrollToPresetId: ScrollToTarget?

    public enum Field: String, Hashable {
      case searchText
    }

    public var editingVisibility: Bool

    public init(
      destination: Destination.State? = nil,
      sections: IdentifiedArrayOf<PresetsListSection.State> = [],
      searchText: String? = nil,
      focusedField: Field? = nil,
      editingVisibility: Bool = false
    ) {
      self.isSearchFieldPresented = searchText != nil
      self.searchText = searchText ?? ""
      self.editingVisibility = editingVisibility
      self.sections = []
    }

    public func sectionIndex(for id: Int) -> Int? { sections.index(id: id) }

    public mutating func updateSection(_ id: Int, presetId: Preset.ID, displayName: String) {
      guard let sectionIndex = sections.index(id: id) else {
        fatalError("unexpected section indexing failure")
      }
      sections[sectionIndex].update(presetId: presetId, displayName: displayName)
    }
  }

  public enum Action: BindableAction {
    case binding(BindingAction<State>)
    case cancelSearchButtonTapped
    case clearScrollToPresetId
    case clearSearchTextField
    case deinitialize
    case delegate(Delegate)
    case destination(PresentationAction<Destination.Action>)
    case editingVisibilityChanged(Bool)
    case fetchPresets
    case initialize
    case searchTextChanged(String)
    case sections(IdentifiedActionOf<PresetsListSection>)
    case selectedSoundFontIdChanged(SoundFont.ID?)
    case showActivePreset
    case showActivePresetNow

    @CasePathable
    public enum Delegate {
      case edit(sectionId: Int, preset: Preset)
    }
  }

  @Dependency(\.defaultDatabase) private var database
  @Shared(.activeState) private var activeState
  @Shared(.confirmPresetHiding) private var confirmPresetHiding
  @Shared(.selectedSoundFontId) private var selectedSoundFontId

  public init() {}

  public var body: some ReducerOf<Self> {
    BindingReducer()
    Reduce<State, Action> { state, action in
      log.action("PresetsList", action)
      switch action {

      case .cancelSearchButtonTapped:
        return dismissSearch(&state)

      case .clearSearchTextField:
        return searchTextChanged(&state, searchText: "")

      case .clearScrollToPresetId:
        state.scrollToPresetId = nil
        return .none

      case .deinitialize:
        return .merge(CancelId.allCases.map { .cancel(id: $0) })

      case .destination(.presented(.alert(.deleteFavoriteConfirmed(let preset)))):
        return deleteFavoriteConfirmed(&state, preset: preset)

      case .destination(.presented(.alert(.hidePresetConfirmed(let preset)))):
        return hidePresetConfirmed(&state, preset: preset)

      case .fetchPresets:
        state.scrollToPresetId = .init(presetId: activeState.activePresetId)
        return generatePresetSections(&state)

      case .initialize:
        return monitorSelectedSoundFontId()

      case .searchTextChanged(let value):
        return searchTextChanged(&state, searchText: value)

      case let .sections(.element(id: sectionId, action: .delegate(action))):
        return processSectionAction(&state, sectionId: sectionId, action: action)

      case .selectedSoundFontIdChanged(let soundFontId):
        return setSoundFont(&state, soundFontId: soundFontId)

      case .showActivePreset:
        return showActivePreset(&state)

      case .showActivePresetNow:
        state.scrollToPresetId = .init(presetId: activeState.activePresetId)
        return .none

      case let .editingVisibilityChanged(editing):
        state.editingVisibility = editing
        return generatePresetSections(&state)

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
    case presetsListMonitorSelectedSoundFontId
    case presetsListShowActivePresetNow
  }
}

extension PresetsList {

  private func deleteFavorite(_ state: inout State, preset: Preset) -> Effect<Action> {
    state.destination = .alert(
      .confirmDeleteFavorite(action: .deleteFavoriteConfirmed(preset), displayName: preset.displayName)
    )
    return .none
  }

  private func deleteFavoriteConfirmed(_ state: inout State, preset: Preset) -> Effect<Action> {
    precondition(preset.isFavorite)
    withDatabaseWriter { db in
      try Preset.delete(preset)
        .execute(db)
    }
    return generatePresetSections(&state).animation(.smooth)
  }

  private func dismissSearch(_ state: inout State) -> Effect<Action> {
    state.isSearchFieldPresented = false
    state.focusedField = nil
    state.scrollToPresetId = nil
    generatePresetSections(&state)
    return .send(.showActivePreset)
  }

  @discardableResult
  private func generatePresetSections(_ state: inout State, soundFontId: SoundFont.ID? = nil) -> Effect<Action> {
    let grouping = state.optionalSearchText != nil ? Self.noGroupingSize : Self.groupingSize
    var presets = (
      state.editingVisibility
      ? Operations.allPresets(for: soundFontId)
      : Operations.presets(for: soundFontId)
    )
    if let searchText = state.optionalSearchText {
      presets = presets.filter {
        $0.displayName.localizedLowercase.contains(searchText.lowercased())
      }
    }

    state.sections = presets.isEmpty ?
      .init(uniqueElements: [PresetsListSection.State(section: 0, presets: [])]) :
      .init(uniqueElements: presets.indices.chunks(ofCount: grouping).map {
        PresetsListSection.State(section: $0.lowerBound, presets: presets[$0])
      })

    return .none
  }

  private func hidePreset(_ state: inout State, preset: Preset) -> Effect<Action> {
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
    $confirmPresetHiding.withLock { $0 = false }
    var preset = preset
    preset.toggleVisibility()
    return generatePresetSections(&state).animation(.smooth)
  }

  private func monitorSelectedSoundFontId() -> Effect<Action> {
    .publisher {
      $selectedSoundFontId
        .publisher
        .removeDuplicates()
        .map { .selectedSoundFontIdChanged($0) }
    }.cancellable(id: CancelId.presetsListMonitorSelectedSoundFontId, cancelInFlight: true)
  }

  private func processSectionAction(
    _ state: inout State,
    sectionId: Int,
    action: PresetsListSection.Action.Delegate
  ) -> Effect<Action> {
    switch action {

    case .createFavorite(let preset):
      _ = preset.clone()
      return generatePresetSections(&state)

    case .deleteFavorite(let preset):
      return deleteFavorite(&state, preset: preset)

    case .editPreset(let preset):
      return .send(.delegate(.edit(sectionId: sectionId, preset: preset)))

    case .headerTapped(scrollTo: let presetId):
      state.scrollToPresetId = .init(presetId: presetId, anchor: .top)
      return .none

    case .hidePreset(let preset):
      return hidePreset(&state, preset: preset)

    case .searchButtonTapped:
      return searchButtonTapped(&state)

    case .selectPreset(let preset):
      return selectPreset(&state, preset: preset)
    }
  }

  private func searchButtonTapped(_ state: inout State) -> Effect<Action> {
    state.isSearchFieldPresented = true
    state.focusedField = .searchText
    state.scrollToPresetId = nil
    return generatePresetSections(&state)
  }

  private func searchTextChanged(_ state: inout State, searchText: String) -> Effect<Action> {
    if searchText != state.searchText {
      state.searchText = searchText
      return generatePresetSections(&state)
    }
    return .none
  }

  private func selectPreset(_ state: inout State, preset: Preset) -> Effect<Action> {
    let changed = activeState.activePresetId != preset.id
    if changed {
      $activeState.withLock {
        $0.activePresetId = preset.id
        $0.activeSoundFontId = preset.soundFontId
      }
    }
    return state.isSearchFieldPresented ? dismissSearch(&state) : .none
  }

  private func setSoundFont(_ state: inout State, soundFontId: SoundFont.ID?) -> Effect<Action> {
    if activeState.activeSoundFontId == soundFontId {
      state.scrollToPresetId = .init(presetId: activeState.activePresetId)
    } else {
      state.scrollToPresetId = nil
    }
    return generatePresetSections(&state, soundFontId: soundFontId)
  }

  private func showActivePreset(_ state: inout State) -> Effect<Action> {
    // Delay scrolling to active preset in case the keyboard was shown. We hide the music keyboard when the text
    // keyboard appears, and restoring it can cause it to obscure the active preset.
    return .run { send in
      @Dependency(\.continuousClock) var clock
      try await clock.sleep(for: Self.delayBeforeShowingActivePreset)
      await send(.showActivePresetNow)
    }.cancellable(id: CancelId.presetsListShowActivePresetNow, cancelInFlight: true)
  }
}

extension PresetsList.Destination.State: Equatable {}
extension PresetsList.Destination.State: _EphemeralState { public typealias Action = Alert }

// MARK: -

public struct PresetsListView: View {
  @Bindable private var store: StoreOf<PresetsList>
  @FocusState private var focusedField: PresetsList.State.Field?

  public init(store: StoreOf<PresetsList>) {
    self.store = store
  }

  public var body: some View {
    VStack(spacing: 0) {
      if store.isSearchFieldPresented {
        searchField
      }
      ScrollViewReader { proxy in
        StyledList {
          ForEach(store.scope(state: \.sections, action: \.sections)) { rowStore in
            PresetsListSectionView(store: rowStore, searching: store.isSearchFieldPresented)
          }
        }
        .onChange(of: store.scrollToPresetId) {
          doScrollTo(proxy: proxy, oldValue: $0, newValue: $1)
        }
      }
      .task {
        await store.send(.initialize).finish()
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
    .animation(.smooth, value: store.sections)
    .alert($store.scope(state: \.destination?.alert, action: \.destination.alert))
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

  private func doScrollTo(
    proxy: ScrollViewProxy,
    oldValue: PresetsList.ScrollToTarget?,
    newValue: PresetsList.ScrollToTarget?
  ) {
    if let newValue {
      withAnimation {
        proxy.scrollTo(newValue.presetId, anchor: newValue.anchor)
        store.send(.clearScrollToPresetId)
      }
    } else {
      withAnimation {
        proxy.scrollTo(0, anchor: .top)
      }
    }
  }
}

private let log: Logger = .init(category: "PresetsList")

#if DEBUG

extension PresetsListView {

  static var preview: some View {
    prepareDependencies { $0.defaultDatabase = previewDatabase() }
    @Shared(.selectedSoundFontId) var selectedSoundFontId
    $selectedSoundFontId.withLock { $0 = 1 }
    return VStack {
      let store = Store(initialState: .init()) { PresetsList() }
      PresetsListView(store: store)
      Toggle("Editing", isOn: Binding(
        get: { store.editingVisibility },
        set: { store.send(.editingVisibilityChanged($0)) }
      )
      )
    }
  }

  static var previewEditing: some View {
    prepareDependencies { $0.defaultDatabase = previewDatabase() }
    @Shared(.selectedSoundFontId) var selectedSoundFontId
    $selectedSoundFontId.withLock { $0 = 1 }
    return PresetsListView(store: Store(initialState: .init(editingVisibility: true)) { PresetsList() })
  }
}

#Preview {
  PresetsListView.preview
}

#endif // DEBUG
