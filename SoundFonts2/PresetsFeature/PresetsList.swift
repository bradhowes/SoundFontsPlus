// Copyright © 2025 Brad Howes. All rights reserved.

import Algorithms
import ComposableArchitecture
import SwiftUI

@Reducer
public struct PresetsList {

  @Reducer(state: .equatable, .sendable, action: .equatable)
  public enum Destination: Equatable {
    case edit(PresetEditor)
  }

  @ObservableState
  public struct State: Equatable {
    @Presents var destination: Destination.State?
    var sections: IdentifiedArrayOf<PresetsListSection.State>
    var editingVisibility: Bool
    var searchText: String
    var isSearchFieldPresented: Bool
    var focusedField: Field?
    var optionalSearchText: String? { isSearchFieldPresented ? searchText : nil }
    var scrollToPresetId: Preset.ID?
    var soundFontId: SoundFont.ID?

    enum Field: String, Hashable {
      case searchText
    }

    public init(editingVisibility: Bool = false, searchText: String? = nil) {
      self.editingVisibility = editingVisibility
      self.isSearchFieldPresented = searchText != nil
      self.searchText = searchText ?? ""
      self.sections = []
    }

    /**
     Update any group that is showing the given preset

     - parameter preset: the preset to update with
     - returns: true if updated
     */
    mutating func update(preset: Preset) {
      for var section in sections where section.update(preset: preset) {
        sections[section.section] = section
        break
      }
    }
  }

  public enum Action: Equatable, BindableAction {
    case binding(BindingAction<State>)
    case clearScrollToPresetId
    case destination(PresentationAction<Destination.Action>)
    case fetchPresets
    case onAppear
    case searchTextChanged(String)
    case sections(IdentifiedActionOf<PresetsListSection>)
    case selectedSoundFontIdChanged(SoundFont.ID?)
    case stop
    case cancelSearchButtonTapped
    case visibilityEditMode(Bool)
    case showActivePreset
  }

  public init() {}

  @Dependency(\.defaultDatabase) var database
  @Shared(.activeState) var activeState

  private let pubisherCancelId = "selectedSoundFontChangedPublisher"

  public var body: some ReducerOf<Self> {
    BindingReducer()
    Reduce<State, Action> { state, action in
      switch action {
      case .clearScrollToPresetId:
        state.scrollToPresetId = nil
        return .none

      case .binding: return .none
      case .cancelSearchButtonTapped: return dismissSearch(&state)
      case .destination(.presented(.edit(.acceptButtonTapped))): return updatePreset(&state)
      case .destination: return .none
      case .fetchPresets: return fetchPresets(&state)
      case .onAppear: return monitorSelectedSoundFont()
      case .searchTextChanged(let value): return searchTextChanged(&state, searchText: value)
      case let .sections(.element(id: _, action: .delegate(action))):
        switch action {
        case let .headerTapped(presetId): return headerTapped(&state, presetId: presetId)
        case .searchButtonTapped: return searchButtonTapped(&state)
        }
      case let .sections(.element(id: _, action: .rows(.element(id: _, action: .delegate(action))))):
        switch action {
        case let .createFavorite(preset): return createPreset(&state, preset: preset)
        case let .editPreset(preset): return editPreset(&state, preset: preset)
        case let .hidePreset(preset): return hidePreset(&state, preset: preset)
        case let .selectPreset(preset): return selectPreset(&state, preset: preset)
        }
      case .sections: return .none
      case .selectedSoundFontIdChanged(let soundFontId): return setSoundFont(&state, soundFontId: soundFontId)
      case .stop: return .cancel(id: pubisherCancelId)
      case .visibilityEditMode(let value): return setEditMode(&state, value: value)
      case .showActivePreset: return showActivePreset(&state)
      }
    }
    .forEach(\.sections, action: \.sections) {
      PresetsListSection()
    }
    .ifLet(\.$destination, action: \.destination)
  }
}

func generatePresetSections(searchText: String?, editing: Bool) -> IdentifiedArrayOf<PresetsListSection.State> {
  let grouping = searchText != nil ? 10_000 : 20
  var presets = editing ? Operations.allPresets : Operations.presets
  if let searchText {
    presets = presets.filter {
      $0.displayName.localizedLowercase.contains(searchText.lowercased())
    }
  }

  return presets.isEmpty ?
    .init(uniqueElements: [PresetsListSection.State(section: 0, presets: [])]) :
    .init(uniqueElements: presets.indices.chunks(ofCount: grouping).map {
      PresetsListSection.State(section: $0.lowerBound, presets: presets[$0])
    })
}

extension PresetsList {

  private func showActivePreset(_ state: inout State) -> Effect<Action> {
    @Shared(.activeState) var activeState
    state.scrollToPresetId = activeState.activePresetId
    return .none
  }

  private func createPreset(_ state: inout State, preset: Preset) -> Effect<Action> {
    return .none
  }

  private func headerTapped(_ state: inout State, presetId: Preset.ID) -> Effect<Action> {
    state.scrollToPresetId = presetId
    return .none
  }

  private func editPreset(_ state: inout State, preset: Preset) -> Effect<Action> {
    state.destination = .edit(PresetEditor.State(preset: preset))
    return .none
  }

  private func fetchPresets(_ state: inout State) -> Effect<Action> {
    state.sections = generatePresetSections(
      searchText: state.optionalSearchText,
      editing: state.editingVisibility
    )
    return .none
  }

  private func hidePreset(_ state: inout State, preset: Preset) -> Effect<Action> {
    Operations.setVisibility(of: preset.id, to: false)
    return .run { send in
      await send(.fetchPresets)
    }.animation(.default)
  }

  private func monitorSelectedSoundFont() -> Effect<Action> {
    return .publisher {
      $activeState.selectedSoundFontId.publisher.map {
        return Action.selectedSoundFontIdChanged($0) }
    }.cancellable(id: pubisherCancelId)
  }

  private func searchButtonTapped(_ state: inout State) -> Effect<Action> {
    state.isSearchFieldPresented = true
    state.focusedField = .searchText
    state.searchText = ""
    return fetchPresets(&state)
  }

  private func dismissSearch(_ state: inout State) -> Effect<Action> {
    state.isSearchFieldPresented = false
    state.focusedField = nil
    state.searchText = ""
    return fetchPresets(&state)
  }

  private func searchTextChanged(_ state: inout State, searchText: String) -> Effect<Action> {
    print(searchText, state.searchText)
    if searchText != state.searchText {
      state.searchText = searchText
      return fetchPresets(&state)
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
    state.editingVisibility = false
    @Dependency(\.defaultDatabase) var database
    @Shared(.activeState) var activeState
    if activeState.activeSoundFontId == soundFontId {
      state.scrollToPresetId = activeState.activePresetId
    } else {
      state.scrollToPresetId = nil
    }
    return fetchPresets(&state)
  }

  private func setEditMode(_ state: inout State, value: Bool) -> Effect<Action> {
    state.editingVisibility = value
    return fetchPresets(&state)
  }

  private func updatePreset(_ state: inout State) -> Effect<Action> {
    guard case let Destination.State.edit(editorState)? = state.destination else { return .none }
    state.update(preset: editorState.preset)
    return fetchPresets(&state)
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

      ScrollViewReader { proxy in
        StyledList {
          ForEach(store.scope(state: \.sections, action: \.sections), id: \.id) { rowStore in
            PresetsListSectionView(store: rowStore, searching: store.isSearchFieldPresented)
          }
        }
        .onChange(of: store.scrollToPresetId) {
          doScrollTo(proxy: proxy, oldValue: $0, newValue: $1)
        }
      }
      .environment(\.editMode, .constant(store.editingVisibility ? EditMode.active : .inactive))
      .onAppear {
        store.send(.onAppear)
      }
      // .animation(.smooth, value: store.sections)
      .sheet(item: $store.scope(state: \.destination?.edit, action: \.destination.edit)) {
        PresetEditorView(store: $0)
      }
      .animation(.smooth, value: store.isSearchFieldPresented)
    }
  }

  private func doScrollTo(proxy: ScrollViewProxy, oldValue: Optional<Preset.ID>, newValue: Optional<Preset.ID>) {
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
    let _ = prepareDependencies { $0.defaultDatabase = try! appDatabase() }
    @Shared(.activeState) var activeState
    $activeState.withLock { $0.selectedSoundFontId = .init(rawValue: 1) }
    return PresetsListView(store: Store(initialState: .init()) { PresetsList() })
  }

  static var previewEditing: some View {
    let _ = prepareDependencies { $0.defaultDatabase = try! appDatabase() }
    @Shared(.activeState) var activeState
    $activeState.withLock { $0.selectedSoundFontId = .init(rawValue: 1) }
    return PresetsListView(store: Store(initialState: .init(editingVisibility: true)) {
      PresetsList()
    })
  }
}

#Preview {
  PresetsListView.preview
}
