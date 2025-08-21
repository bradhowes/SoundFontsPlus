// Copyright © 2025 Brad Howes. All rights reserved.

import Algorithms
import ComposableArchitecture
import SwiftUI

@Reducer
public struct PresetsList {

  @ObservableState
  public struct State: Equatable {
    var sections: IdentifiedArrayOf<PresetsListSection.State>
    var searchText: String
    var isSearchFieldPresented: Bool
    var focusedField: Field?
    var optionalSearchText: String? { isSearchFieldPresented ? searchText : nil }
    var scrollToPresetId: Preset.ID?
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

  public enum Action: BindableAction, Equatable {
    case binding(BindingAction<State>)
    case cancelSearchButtonTapped
    case clearScrollToPresetId
    case delegate(Delegate)
    case fetchPresets
    case onAppear
    case searchTextChanged(String)
    case sections(IdentifiedActionOf<PresetsListSection>)
    case selectedSoundFontIdChanged(SoundFont.ID?)
    case showActivePreset
    case visibilityEditModeChanged(Bool)

    public enum Delegate: Equatable {
      case edit(sectionId: Int, preset: Preset)
    }
  }

  public init() {}

  private enum CancelId {
    case monitorSelectedSoundFontId
  }

  @Dependency(\.defaultDatabase) var database
  @Shared(.activeState) var activeState

  public var body: some ReducerOf<Self> {
    BindingReducer()
    Reduce<State, Action> { state, action in
      switch action {
      case .binding:
        return .none

      case .cancelSearchButtonTapped:
        return dismissSearch(&state)

      case .clearScrollToPresetId:
        state.scrollToPresetId = nil
        return .none

      case .delegate:
        return .none

      case .fetchPresets:
        return generatePresetSections(&state)

      case .onAppear:
        return monitorSelectedSoundFontId()

      case .searchTextChanged(let value):
        return searchTextChanged(&state, searchText: value)

        // Preset sections delegated actions
      case let .sections(.element(id: _, action: .delegate(action))):
        switch action {

        case let .headerTapped(presetId):
          state.scrollToPresetId = presetId
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

        case let .editPreset(preset):
          return .send(.delegate(.edit(sectionId: sectionId, preset: preset)))

        case let .hideOrDeletePreset(preset):
          return hideOrDeletePreset(&state, preset: preset)

        case let .selectPreset(preset):
          return selectPreset(&state, preset: preset)
        }

      case .sections:
        return .none

      case .selectedSoundFontIdChanged(let soundFontId):
        return setSoundFont(&state, soundFontId: soundFontId)

      case .showActivePreset:
        state.scrollToPresetId = activeState.activePresetId
        return .none

      case let .visibilityEditModeChanged(editing):
        state.visibilityEditMode = editing ? .active : .inactive
        return generatePresetSections(&state)
      }
    }
    .forEach(\.sections, action: \.sections) {
      PresetsListSection()
    }
  }
}

extension PresetsList {

  private func dismissSearch(_ state: inout State) -> Effect<Action> {
    state.isSearchFieldPresented = false
    state.focusedField = nil
    return generatePresetSections(&state)
  }

  private func generatePresetSections(_ state: inout State) -> Effect<Action> {
    let grouping = state.optionalSearchText != nil ? 10_000 : 20
    var presets = state.visibilityEditMode == .active ? Operations.allPresets : Operations.presets
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

  private func hideOrDeletePreset(_ state: inout State, preset: Preset) -> Effect<Action> {
    if preset.isFavorite {
      try? database.write { try Preset.delete(preset).execute($0) }
    } else {
      var preset = preset
      preset.toggleVisibility()
    }
    return generatePresetSections(&state)
  }

  private func monitorSelectedSoundFontId() -> Effect<Action> {
    .publisher {
      $activeState.selectedSoundFontId
        .publisher
        .map { .selectedSoundFontIdChanged($0) }
    }.cancellable(id: CancelId.monitorSelectedSoundFontId, cancelInFlight: true)
  }

  private func searchButtonTapped(_ state: inout State) -> Effect<Action> {
    state.isSearchFieldPresented = true
    state.focusedField = .searchText
    return generatePresetSections(&state)
  }

  private func searchTextChanged(_ state: inout State, searchText: String) -> Effect<Action> {
    print(searchText, state.searchText)
    if searchText != state.searchText {
      state.searchText = searchText
      return generatePresetSections(&state)
    }
    return .none
  }

  private func selectPreset(_ state: inout State, preset: Preset) -> Effect<Action> {
    $activeState.withLock {
      $0.activePresetId = preset.id
      $0.activeSoundFontId = preset.soundFontId
    }
    return state.isSearchFieldPresented ? dismissSearch(&state) : .none
  }

  private func setActivePresetId(_ state: inout State, _ presetId: Preset.ID?) {
    $activeState.withLock {
      $0.activePresetId = presetId
    }
  }

  private func setSoundFont(_ state: inout State, soundFontId: SoundFont.ID?) -> Effect<Action> {
    if activeState.activeSoundFontId == soundFontId {
      state.scrollToPresetId = activeState.activePresetId
    } else {
      state.scrollToPresetId = nil
    }
    return generatePresetSections(&state)
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
        store.send(.onAppear)
      }
    }
    .animation(.smooth, value: store.isSearchFieldPresented)
    .animation(.smooth, value: store.visibilityEditMode)
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
      Spacer()
      Button {
        store.send(.cancelSearchButtonTapped)
      } label: {
        Image(systemName: "xmark")
      }
    }
    .padding(EdgeInsets(top: 8, leading: 8, bottom: 0, trailing: 8))
  }

  private func doScrollTo(proxy: ScrollViewProxy, oldValue: Preset.ID?, newValue: Preset.ID?) {
    if let newValue {
      withAnimation {
        proxy.scrollTo(newValue)
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
    @Shared(.activeState) var activeState
    $activeState.withLock { $0.selectedSoundFontId = .init(rawValue: 1) }
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
    @Shared(.activeState) var activeState
    $activeState.withLock { $0.selectedSoundFontId = .init(rawValue: 1) }
    return PresetsListView(store: Store(initialState: .init(visibilityEditMode: true)) { PresetsList() })
  }
}

#Preview {
  PresetsListView.preview
}
