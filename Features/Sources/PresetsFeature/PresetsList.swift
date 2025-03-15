//// Copyright © 2025 Brad Howes. All rights reserved.
//
//import Algorithms
//import ComposableArchitecture
//import SwiftData
//import SwiftUI
//import Models
//
//@Reducer
//public struct PresetsList {
//
//  @Reducer
//  public enum Destination {
//    case edit(PresetEditor)
//  }
//
//  @ObservableState
//  public struct State {
//    @Presents var destination: Destination.State?
//    let soundFont: SoundFont
//    var rows: IdentifiedArrayOf<PresetsListSection.State>
//    @Shared(.activeState) var activeState
//
//    public init(soundFont: SoundFont) {
//      self.soundFont = soundFont
//      self.rows = generatePresetSections(soundFont: soundFont)
//    }
//  }
//
//  public enum Action {
//    case changeVisibility
//    case destination(PresentationAction<Destination.Action>)
//    case fetchSoundFonts
//    case onAppear
//    case rows(IdentifiedActionOf<PresetsListSection>)
//    case selectedSoundFontIdChanged(SoundFont.ID?)
//  }
//
//  public init() {}
//
//  public var body: some ReducerOf<Self> {
//    Reduce<State, Action> { state, action in
//      switch action {
//
//      case .changeVisibility:
//        return .none
//
//      case .destination(.dismiss):
//        return .none
//
//      case .destination:
//        return .none
//
//      case .fetchSoundFonts:
//        fetchPresets(&state, key: state.activeState.activeSoundFontId)
//        return .none
//
//      case .onAppear:
//        print("onAppear")
//        return .publisher {
//          state.$activeState.selectedSoundFontId.publisher.map {
//            print("selectedSoundFontKeyChanged")
//            return Action.selectedSoundFontIdChanged($0) }
//        }
//
//      case let .rows(.element(id: _, action: .rows(.element(id: _, action: .delegate(.editPreset(preset)))))):
//        state.destination = .edit(PresetEditor.State(preset: preset))
//        return .none
//
//      case let .rows(.element(id: _, action: .rows(.element(id: _, action: .delegate(.hidePreset(preset)))))):
//        hidePreset(&state, preset: preset)
//        return .none
//
//      case let .rows(.element(id: _, action: .rows(.element(id: _, action: .delegate(.selectPreset(preset)))))):
//        state.$activeState.withLock {
//          $0.setActivePresetId(preset.id)
//          $0.setActiveSoundFontId(preset.soundFontId)
//        }
//        return .none
//
//      case .rows:
//        return .none
//
//      case .selectedSoundFontIdChanged(let key):
//        fetchPresets(&state, key: key)
//        return .none
//      }
//    }
//    .forEach(\.rows, action: \.rows) {
//      PresetsListSection()
//    }
//    .ifLet(\.$destination, action: \.destination)
//  }
//}
//
//// extension PresetsList.Destination.State: Equatable {}
//
//private func generatePresetSections(soundFont: SoundFont) -> IdentifiedArrayOf<PresetsListSection.State> {
//  let grouping = 10
//  let presets = soundFont.presets
//  return .init(uniqueElements: presets.indices.chunks(ofCount: grouping).map { range in
//    PresetsListSection.State(section: range.lowerBound, presets: Array(presets[range]))
//  })
//}
//
//extension PresetsList {
//
//  private func fetchPresets(_ state: inout State, key: SoundFont.ID?) {
//    guard let key else { return }
//    @Dependency(\.defaultDatabase) var database
//    do {
//      let soundFont = try database.read { try SoundFont.fetchOne($0, id: key) }
//      if let soundFont {
//        state.rows = generatePresetSections(soundFont: soundFont)
//      } else {
//        state.rows = []
//      }
//    } catch {
//      state.rows = []
//      print("failed to fetch sound font key \(key)")
//    }
//  }
//
//  private func setActivePresetId(_ state: inout State, _ presetId: Preset.ID?) {
//    state.$activeState.withLock {
//      $0.setActivePresetId(presetId)
//    }
//  }
//
//  private func hidePreset(_ state: inout State, preset: Preset) {
//    @Dependency(\.defaultDatabase) var database
//    if preset.id == state.activeState.activePresetId {
//      // Locate the first preset that is not hidden to become the active one
//      let presets = state.soundFont.presets
//      if let found = (0..<Int(preset.id.rawValue)).last(where: { presets[$0].visible }) {
//        print("before - \(found)")
//        setActivePresetId(&state, presets[found].id)
//      } else if let found = (Int(preset.id.rawValue + 1)..<presets.count).first(where: { presets[$0].visible }) {
//        print("after - \(found)")
//        setActivePresetId(&state, presets[found].id)
//      } else {
//        print("nothing found")
//        setActivePresetId(&state, nil)
//      }
//    }
//
//    var preset = preset
//    do {
//      let rc = try database.write {
//        try preset.updateChanges($0) {
//          $0.visible = false
//        }
//      }
//    } catch {
//
//    }
//
//    state.rows = generatePresetSections(soundFont: state.soundFont)
//  }
//}
//
//public struct PresetsListView: View {
//  @Bindable private var store: StoreOf<PresetsList>
//
//  public init(store: StoreOf<PresetsList>) {
//    self.store = store
//  }
//
//  public var body: some View {
//    List {
//      ForEach(store.scope(state: \.rows, action: \.rows), id: \.id) { rowStore in
//        PresetsListSectionView(store: rowStore)
//      }
//    }
//    .listSectionSpacing(.custom(-14.0))
//    .onAppear {
//      store.send(.onAppear)
//    }
//    .sheet(
//      item: $store.scope(state: \.destination?.edit, action: \.destination.edit)
//    ) { editorStore in
//      PresetEditorView(store: editorStore)
//    }
//    .navigationTitle("Presets")
//    .toolbar {
//      Button {
//      } label: {
//        Image(systemName: "checklist")
//      }
//      Button {
//      } label: {
//        Image(systemName: "magnifyingglass")
//      }
//    }
//  }
//}
//
//private func mockSoundFont() -> (SoundFont, [Preset]) {
//  @Dependency(\.defaultDatabase) var database
//  do {
//    let soundFont = try database.write {
//      try SoundFont.mock($0, name: "First One", presetNames: ["A", "B", "C"], tags: [])
//    }
//    let presets = try database.read {
//      try soundFont.visiblePresetsQuery.fetchAll($0)
//    }
//    return (soundFont, presets)
//  } catch {
//    fatalError()
//  }
//}
//
//extension PresetsListView {
//  static var preview: some View {
//    let (soundFont, _) = mockSoundFont()
//    return VStack {
//      PresetsListView(store: Store(initialState: .init(soundFont: soundFont)) { PresetsList() })
//    }
//  }
//}
//
//#Preview {
//  PresetsListView.preview
//}
