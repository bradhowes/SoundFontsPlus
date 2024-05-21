import ComposableArchitecture
import SwiftData
import SwiftUI
import Models

@Reducer
public struct PresetListFeature {

  //  @Reducer(state: .equatable)
  //  enum Path {
  //    case soundFontDetail(SoundFontDetail)
  //    case presetDetail(PresetDetail)
  //    case tagManager
  //  }

  @ObservableState
  public struct State: Equatable {
    // var path = StackState<Path.State>()

    var activeSoundFontId: SoundFont.ID
    var selectedSoundFontId: SoundFont.ID
    var activePresetId: Preset.ID

    var isSearchPresented = false
    var searchText = ""
    var lastSearchText = ""

    public init(soundFontId: SoundFont.ID, presetId: Preset.ID) {
      activeSoundFontId = soundFontId
      selectedSoundFontId = soundFontId
      activePresetId = presetId
    }
  }

  public enum Action: BindableAction {
    case binding(BindingAction<State>)
    case presetButtonTapped(presetId: Preset.ID)
    case searchButtonTapped
  }

  public var body: some ReducerOf<Self> {
    BindingReducer()
    Reduce { state, action in
      switch action {
      case let .presetButtonTapped(presetId):
        if state.isSearchPresented {
          state.lastSearchText = state.searchText
          state.searchText = ""
          state.isSearchPresented = false
        }
        state.activePresetId = presetId
        return .none

      case .searchButtonTapped:
        state.searchText = state.lastSearchText
        state.isSearchPresented = true
        return .none
      case .binding:
        return .none
      }
    }
  }
}

public struct PresetListView: View {
  @Query private var presets: [Preset]
  @Bindable private var store: StoreOf<PresetListFeature>

  public init(store: StoreOf<PresetListFeature>) {
    self.store = store
    self._presets = Query(Preset.fetchDescriptor(for: store.selectedSoundFontId),
                          animation: .default)
  }

  public var body: some View {
    ScrollViewReader { proxy in
      NavigationStack {
        List(presets) { preset in
          if store.searchText.isEmpty || preset.name.localizedStandardContains(store.searchText) {
            PresetButtonView(
              preset: preset,
              activePresetId: store.activePresetId,
              action: { store.send(.presetButtonTapped(presetId: preset.persistentModelID)) } )
          }
        }
        .searchable(text: $store.searchText,
                    isPresented: $store.isSearchPresented,
                    placement: .navigationBarDrawer,
                    prompt: "Preset")
        .onChange(of: store.selectedSoundFontId) { oldValue, newValue in
          if oldValue != newValue && newValue == store.activeSoundFontId {
            scrollToActivePreset(proxy: proxy)
          }
        }
        .onChange(of: store.isSearchPresented) { oldValue, newValue in
          if !newValue {
            scrollToActivePreset(proxy: proxy)
          }
        }
        .navigationTitle("Presets")
        .toolbar {
          Button(
            LocalizedStringKey("Search"),
            systemImage: "magnifyingglass",
            action: { store.send(.searchButtonTapped) }
          )
        }
      }
      .onTapGesture(count: 2) {
        proxy.scrollTo(presets[0].persistentModelID)
      }
    }
  }

  @MainActor
  func scrollToActivePreset(proxy: ScrollViewProxy) {
    if store.selectedSoundFontId == store.activeSoundFontId {
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
        proxy.scrollTo(store.activePresetId)
      }
    }
  }
}

struct PresetListView_Previews: PreviewProvider {
  static let modelContainer = VersionedModelContainer.make(isTemporary: true)
  static var soundFonts: [SoundFont] { modelContainer.mainContext.allSoundFonts() }

  @State static var store = Store(initialState: PresetListFeature.State(soundFontId: soundFonts[0].persistentModelID, presetId: soundFonts[0].orderedPresets[0].persistentModelID)) {
    PresetListFeature()
  }

  static var previews: some View {
    PresetListView(store: store)
    .environment(\.modelContext, modelContainer.mainContext)
  }
}
