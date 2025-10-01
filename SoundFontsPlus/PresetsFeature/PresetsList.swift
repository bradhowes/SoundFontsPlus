// Copyright © 2025 Brad Howes. All rights reserved.

import Algorithms
import ComposableArchitecture
import Dependencies
import SwiftUI

@Reducer
public struct PresetsList {
  public static let groupingSize = 20
  public static let noGroupingSize = 10_000
  public static let delayBeforeShowingActivePreset: Duration = .milliseconds(100)
  public static let playNoteDuration: Duration = .milliseconds(250)

  @Reducer(state: .equatable, action: .equatable)
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

  @ObservableState
  public struct State: Equatable {
    @Presents var destination: Destination.State?
    var sections: IdentifiedArrayOf<PresetsListSection.State>
    var searchText: String
    var isSearchFieldPresented: Bool
    var focusedField: Field?
    var optionalSearchText: String? { isSearchFieldPresented ? searchText : nil }
    var scrollToPresetId: ScrollToTarget?
    var soundFontId: SoundFont.ID?

    enum Field: String, Hashable {
      case searchText
    }

    var visibilityEditMode: EditMode

    public init(searchText: String? = nil, visibilityEditMode: Bool = false) {
      self.isSearchFieldPresented = searchText != nil
      self.searchText = searchText ?? ""
      self.visibilityEditMode = visibilityEditMode ? .active : .inactive
      self.sections = []
    }
  }

  public enum Action: BindableAction {
    case binding(BindingAction<State>)
    case cancelSearchButtonTapped
    case clearScrollToPresetId
    case clearSearchTextField
    case delegate(Delegate)
    case destination(PresentationAction<Destination.Action>)
    case fetchPresets
    case initialize
    case searchTextChanged(String)
    case sections(IdentifiedActionOf<PresetsListSection>)
    case selectedSoundFontIdChanged(SoundFont.ID?)
    case showActivePreset
    case showActivePresetNow
    case stop // only used for testing
    case visibilityEditModeChanged(Bool)

    public enum Delegate: Equatable {
      case edit(sectionId: Int, preset: Preset)
    }
  }

  public init() {}

  public var body: some ReducerOf<Self> {
    BindingReducer()
    Reduce<State, Action> { state, action in
      switch action {
      case .binding:
        return .none

      case .cancelSearchButtonTapped:
        return dismissSearch(&state)

      case .clearSearchTextField:
        return searchTextChanged(&state, searchText: "")

      case .clearScrollToPresetId:
        state.scrollToPresetId = nil
        return .none

      case .delegate:
        return .none

      case .destination(.presented(.alert(.deleteFavoriteConfirmed(let preset)))):
        return deleteFavoriteConfirmed(&state, preset: preset)

      case .destination(.presented(.alert(.hidePresetConfirmed(let preset)))):
        return hidePresetConfirmed(&state, preset: preset)

      case .destination(.dismiss):
        return .none

      case .fetchPresets:
        state.scrollToPresetId = .init(presetId: activeState.activePresetId)
        return generatePresetSections(&state)

      case .initialize:
        return monitorSelectedSoundFontId()

      case .searchTextChanged(let value):
        return searchTextChanged(&state, searchText: value)

      case let .sections(.element(id: _, action: .delegate(action))):
        switch action {

        case let .headerTapped(presetId):
          state.scrollToPresetId = .init(presetId: presetId, anchor: .top)
          return .none

        case .searchButtonTapped:
          return searchButtonTapped(&state)
        }

        // Preset delegated actions
      case let .sections(.element(id: sectionId, action: .rows(.element(id: _, action: .delegate(action))))):
        switch action {

        case let .createFavorite(preset):
          _ = preset.clone()
          return generatePresetSections(&state)

        case let .deleteFavorite(preset):
          return deleteFavorite(&state, preset: preset)

        case let .editPreset(preset):
          return .send(.delegate(.edit(sectionId: sectionId, preset: preset)))

        case let .hidePreset(preset):
          return hidePreset(&state, preset: preset)

        case let .selectPreset(preset):
          return selectPreset(&state, preset: preset)
        }

      case .sections:
        return .none

      case .selectedSoundFontIdChanged(let soundFontId):
        return setSoundFont(&state, soundFontId: soundFontId)

      case .showActivePreset:
        return showActivePreset(&state)

      case .showActivePresetNow:
        state.scrollToPresetId = .init(presetId: activeState.activePresetId)
        return .none

      case .stop:
        return .cancel(id: CancelId.monitorSelectedSoundFontId)

      case let .visibilityEditModeChanged(editing):
        state.visibilityEditMode = editing ? .active : .inactive
        return generatePresetSections(&state)
      }
    }
    .forEach(\.sections, action: \.sections) {
      PresetsListSection()
    }
    .ifLet(\.destination, action: \.destination)
  }

  @Dependency(\.defaultDatabase) var database
  @Shared(.activeState) var activeState
  @Shared(.selectedSoundFontId) var selectedSoundFontId
  @Shared(.confirmPresetHiding) var confirmPresetHiding

  private enum CancelId {
    case monitorSelectedSoundFontId
    case playNote
    case showActivePresetNow
  }
}

extension PresetsList.Destination.State: _EphemeralState {
  public typealias Action = Alert
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
    var presets = state.visibilityEditMode == .active ? Operations.allPresets(for: soundFontId) : Operations.presets(for: soundFontId)
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
    }.cancellable(id: CancelId.monitorSelectedSoundFontId, cancelInFlight: true)
  }

  private func playNote() -> Effect<Action> {
    @Shared(.synthAudioUnit) var synthAudioUnit
    guard let synth = synthAudioUnit?.synth else { return .none }

    @Shared(.playSoundOnPresetChange) var playSoundOnPresetChange
    guard playSoundOnPresetChange else { return .none }
    return .run { _ in
      @Dependency(\.continuousClock) var clock
      synth.sendNoteOn(note: 60)
      try? await clock.sleep(for: Self.playNoteDuration)
      synth.sendNoteOff(note: 60)
    }.cancellable(id: CancelId.playNote, cancelInFlight: true)
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
    return .concatenate(
      state.isSearchFieldPresented ? dismissSearch(&state) : .none,
      changed ? .none : playNote()
    )
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
    }.cancellable(id: CancelId.showActivePresetNow, cancelInFlight: true)
  }
}

public struct PresetsListView: View {
  @Bindable private var store: StoreOf<PresetsList>
  @FocusState var focusedField: PresetsList.State.Field?

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
          .environment(\.editMode, $store.visibilityEditMode)
        }
        .onChange(of: store.scrollToPresetId) {
          doScrollTo(proxy: proxy, oldValue: $0, newValue: $1)
        }
      }
      .onAppear {
        store.send(.fetchPresets)
      }
      .task {
        await store.send(.initialize).finish()
      }
    }
    .animation(.smooth, value: store.isSearchFieldPresented)
    .animation(.smooth, value: store.visibilityEditMode)
    .animation(.smooth, value: store.sections)
    .alert($store.scope(state: \.destination?.alert, action: \.destination.alert))
  }

  private var searchField: some View {
    HStack {
      TextField("Search", text: $store.searchText.sending(\.searchTextChanged))
        .textFieldStyle(.roundedBorder)
        .focused($focusedField, equals: .searchText)
        .autocorrectionDisabled()
        .autocapitalization(.none)
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

extension PresetsListView {

  static var preview: some View {
    // swiftlint:disable:next force_try
    prepareDependencies { $0.defaultDatabase = try! appDatabase() }
    @Shared(.selectedSoundFontId) var selectedSoundFontId
    $selectedSoundFontId.withLock { $0 = .init(rawValue: 1) }
    return VStack {
      let store = Store(initialState: .init()) { PresetsList() }
      PresetsListView(store: store)
      Toggle("Editing", isOn: Binding(
        get: { store.visibilityEditMode == .active },
        set: { store.send(.visibilityEditModeChanged($0)) }
      )
      )
    }
  }

  static var previewEditing: some View {
    // swiftlint:disable:next force_try
    prepareDependencies { $0.defaultDatabase = try! appDatabase() }
    @Shared(.selectedSoundFontId) var selectedSoundFontId
    $selectedSoundFontId.withLock { $0 = .init(rawValue: 1) }
    return PresetsListView(store: Store(initialState: .init(visibilityEditMode: true)) { PresetsList() })
  }
}

#Preview {
  PresetsListView.preview
}
