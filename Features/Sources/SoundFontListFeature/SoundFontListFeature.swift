import ComposableArchitecture
import SwiftData
import SwiftUI
import Models


@Reducer
public struct SoundFontListFeature {

  @ObservableState
  public struct State: Equatable {

    var tagFilteredSoundFontListState: TagFilteredSoundFontListFeature.State

    var addingSoundFonts: Bool = false
    var pickerResults: [URL] = []
    var showingAddedSummary: Bool = false

    var addedSummary: LocalizedStringKey = "" {
      didSet {
        showingAddedSummary = addedSummary != ""
      }
    }

    public init(tagFilteredSoundFontListState: TagFilteredSoundFontListFeature.State) {
      self.tagFilteredSoundFontListState = tagFilteredSoundFontListState
    }
  }

  public enum Action: BindableAction {
    case binding(BindingAction<State>)
    case tagSelectionChanged(tagId: Tag.ID)
  }

  public var body: some ReducerOf<Self> {
    BindingReducer()
    Reduce { state, action in
      switch action {
      case .binding:
        return .none

      case let .tagSelectionChanged(tagId):
        state.tagFilteredSoundFontListState.tagPicker.activeTagId = tagId
        return .none
      }
    }
  }
}

public struct SoundFontListView: View {
  @Environment(\.modelContext) var modelContext: ModelContext

  @Bindable private var store: StoreOf<SoundFontListFeature>

  public init(store: StoreOf<SoundFontListFeature>) {
    self.store = store
  }

  public var body: some View {
    NavigationStack {
      TagFilteredSoundFontListView(store: store.scope(state: \.tagFilteredSoundFontListState, action: \.never)
        .navigationTitle("Files")
        .toolbar {
          ToolbarItemGroup {
            TagPickerView(activeTagId: $store.activeTagId)
            Button(LocalizedStringKey("Add"),
                   systemImage: "plus",
                   action: { store.addingSoundFonts = true })
          }
        }
    }
//    .sheet(isPresented: $store.addingSoundFonts) {
//      SF2PickerView(pickerResults: $store.pickerResults)
//    }.onChange(of: store.pickerResults) { _, newValue in
//      if !newValue.isEmpty {
//        addSoundFonts(urls: newValue)
//      }
//    }.alert("Add Complete", isPresented: $store.showingAddedSummary) {
//      // add buttons here
//    } message: {
//      Text(store.addedSummary)
//    }
  }
}

private extension SoundFontListView {

  @MainActor
  func addSoundFonts(urls: [URL]) {
    let result = modelContext.picked(urls: urls)
    store.addedSummary = generateResultMessage(result: result)
    store.pickerResults = []
  }

  @MainActor
  func generateResultMessage(result: ModelContext.PickedStatus) -> LocalizedStringKey {
    if result.bad.isEmpty {
      return "^[Successfuly added \(result.good) file](inflect: true)."
    } else if result.good == 0 {
      return "^[Failed to add \(result.bad.count) file](inflect: true)."
    } else {
      return "^[Successfully added \(result.good) file but, failed to add \(result.bad.count)](inflect: true)."
    }
  }
}

struct SoundFontFontList_Previews: PreviewProvider {
  static let modelContainer = VersionedModelContainer.make(isTemporary: true)

  @MainActor
  struct PreviewState {
    let allSoundFonts: [SoundFont]
    let tags: [Tag]
    let activeSoundFont: SoundFont
    let selectedSoundFont: SoundFont
    let otherSoundFont: SoundFont
    let allTagId: Tag.ID

    @Shared var activeSoundFontId: SoundFont.ID
    @Shared var selectedSoundFontId: SoundFont.ID
    @Shared var activeTagId: Tag.ID
    @Shared var activePresetId: Preset.ID

    init() {
      let tags = modelContainer.mainContext.tags()
      let allSoundFonts = modelContainer.mainContext.allSoundFonts()

      self.allSoundFonts = allSoundFonts
      self.tags = tags
      self.activeSoundFont = allSoundFonts[0]
      self.selectedSoundFont = allSoundFonts[1]
      self.otherSoundFont = allSoundFonts[2]
      self.allTagId = (tags.first(where: { $0.name == "All" })!).persistentModelID

      _activeSoundFontId = Shared(allSoundFonts[0].persistentModelID)
      _selectedSoundFontId = Shared(allSoundFonts[1].persistentModelID)
      _activeTagId = Shared(tags[1].persistentModelID)
      _activePresetId = Shared(allSoundFonts[0].orderedPresets[0].persistentModelID)

      _ = modelContainer.mainContext.mockSoundFont(name: "Foo", kind: .installed)
      _ = modelContainer.mainContext.mockSoundFont(name: "Bar", kind: .installed)
      _ = modelContainer.mainContext.mockSoundFont(name: "Bar External", kind: .external)
    }

    func makeStore() -> StoreOf<SoundFontListFeature> {
      StoreOf<SoundFontListFeature>(initialState: makeSoundFontListState()) { SoundFontListFeature() }
    }

    func makeSoundFontListState() -> SoundFontListFeature.State {
      .init(
        tagFilteredSoundFontListState: TagFilteredSoundFontListFeature.State(
          selectedSoundFontId: $selectedSoundFontId,
          activeSoundFontId: SharedReader($activeSoundFontId),
          activePresetId: SharedReader($activePresetId),
          tagPicker: makeTagPickerState()
        )
      )
    }

    func makeTagPickerState() -> TagPickerFeature.State {
      .init(activeTagId: $activeTagId, allTagId: allTagId) }
  }

  static var previewState = PreviewState()
  static var store = previewState.makeStore()

  static var previews: some View {
    SoundFontListView(store: store)
      .modelContainer(modelContainer)
      .modelContext(modelContainer.mainContext)
  }
}

extension ModelContext {

  fileprivate func mockSoundFont(name: String, kind: Location.Kind) -> SoundFont {
    let location: Location = .init(kind: kind, url: .currentDirectory(), raw: nil)
    let soundFont = SoundFont(location: location, name: name)

    self.insert(soundFont)

    let presets = [
      Preset(owner: soundFont, index: 0, name: "One"),
      Preset(owner: soundFont, index: 1, name: "Two"),
      Preset(owner: soundFont, index: 2, name: "Three")
    ]

    for preset in presets {
      soundFont.presets.append(preset)
    }

    try? self.save()

    soundFont.addDefaultTags()

    try? self.save()

    return soundFont
  }
}
