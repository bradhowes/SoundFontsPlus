//import OSLog
//import ComposableArchitecture
//import SwiftData
//import SwiftUI
//import Models
//
//let log = Logger(subsystem: "com.braysoftware.SoundFonts2.Models",
//                 category: "SoundFontListFeature")
//
//@Reducer
//public struct SoundFontListFeature {
//
//  @ObservableState
//  public struct State: Equatable {
//
//    var activeSoundFontId: SoundFont.ID
//    var selectedSoundFontId: SoundFont.ID
//    var activePresetId: Preset.ID
//    var activeTagId: Tag.ID
//
//    var addingSoundFonts: Bool = false
//    var pickerResults: [URL] = []
//    var showingAddedSummary: Bool = false
//
//    var addedSummary: LocalizedStringKey = "" {
//      didSet {
//        showingAddedSummary = addedSummary != ""
//      }
//    }
//
//    public init(activeTagId: Tag.ID, soundFontId: SoundFont.ID, presetId: Preset.ID) {
//      self.activeTagId = activeTagId
//      self.activeSoundFontId = soundFontId
//      self.selectedSoundFontId = soundFontId
//      self.activePresetId = presetId
//    }
//  }
//
//  public enum Action: BindableAction {
//    case binding(BindingAction<State>)
//    case soundFontButtonTapped(soundFontId: SoundFont.ID)
//    case tagSelectionChanged(tagId: Tag.ID)
//  }
//
//  public var body: some ReducerOf<Self> {
//    BindingReducer()
//    Reduce { state, action in
//      switch action {
//      case let .soundFontButtonTapped(soundFontId):
//        state.selectedSoundFontId = soundFontId
//        return .none
//
//      case .binding:
//        return .none
//
//      case let .tagSelectionChanged(tagId):
//        state.activeTagId = tagId
//        return .none
//      }
//    }
//  }
//}
//
//public struct SoundFontListView: View {
//  @Environment(\.modelContext) var modelContext: ModelContext
//
//  @Bindable private var store: StoreOf<SoundFontListFeature>
//
//  public init(store: StoreOf<SoundFontListFeature>) {
//    self.store = store
//  }
//
//  public var body: some View {
//    NavigationStack {
//      TagFilteredSoundFontListView(tagId: store.activeTagId,
//                                   activeSoundFontId: $store.activeSoundFontId,
//                                   selectedSoundFontId: $store.selectedSoundFontId,
//                                   activePresetId: $store.activePresetId)
//      .navigationTitle("Files")
//      .toolbar {
//        ToolbarItemGroup {
//          TagPickerView(activeTagId: $store.activeTagId)
//          Button(LocalizedStringKey("Add"),
//                 systemImage: "plus",
//                 action: { store.addingSoundFonts = true })
//        }
//      }
//    }.sheet(isPresented: $store.addingSoundFonts) {
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
//  }
//}
//
//private extension SoundFontListView {
//
//  @MainActor
//  func addSoundFonts(urls: [URL]) {
//    let result = modelContext.picked(urls: urls)
//    store.addedSummary = generateResultMessage(result: result)
//    store.pickerResults = []
//  }
//
//  @MainActor
//  func generateResultMessage(result: ModelContext.PickedStatus) -> LocalizedStringKey {
//    if result.bad.isEmpty {
//      return "^[Successfuly added \(result.good) file](inflect: true)."
//    } else if result.good == 0 {
//      return "^[Failed to add \(result.bad.count) file](inflect: true)."
//    } else {
//      return "^[Successfully added \(result.good) file but, failed to add \(result.bad.count)](inflect: true)."
//    }
//  }
//}
//
//struct SoundFontsListView_Previews: PreviewProvider {
//  static let modelContainer = VersionedModelContainer.make(isTemporary: true)
//  static let activeTag = modelContainer.mainContext.ubiquitousTag(.all)
//  static let soundFont = modelContainer.mainContext.allSoundFonts()[0]
//
//  @State static var store = Store(initialState: SoundFontListFeature.State(
//    activeTagId: activeTag.persistentModelID,
//    soundFontId: soundFont.persistentModelID,
//    presetId: soundFont.orderedPresets[0].persistentModelID
//  )) {
//      SoundFontListFeature()
//    }
//
//  static var previews: some View {
//    SoundFontListView(store: store)
//      .environment(\.modelContext, modelContainer.mainContext)
//  }
//}
