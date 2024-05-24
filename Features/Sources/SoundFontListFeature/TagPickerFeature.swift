// Copyright © 2024 Brad Howes. All rights reserved.

import ComposableArchitecture
import Foundation
import SwiftData
import SwiftUI
import Models

@Reducer
struct TagPickerFeature: Reducer {

  @ObservableState
  struct State: Equatable {
    @Shared var activeTagId: Tag.ID
    let allTagId: Tag.ID
  }

  enum Action: BindableAction {
    case showAll
    case binding(BindingAction<State>)
  }

  var body: some ReducerOf<Self> {
    BindingReducer()

    Reduce<State, Action> { state, action in
      switch action {
      case .showAll:
        return .none

      case .binding(\.activeTagId):
        print("tag changed")
        return .none

      case .binding:
        print("other changed")
        return .none
      }
    }
  }
}

struct TagPickerView: View {
  @Environment(\.modelContext) private var modelContext
  @Query(sort: \Tag.name) private var tags: [Tag]

  @Bindable private var store: StoreOf<TagPickerFeature>

  init(store: StoreOf<TagPickerFeature>) {
    self.store = store
  }

  var body: some View {
    Picker("Tag", selection: $store.activeTagId) {
      ForEach(tags) { tag in
        Text(tag.name)
          .tag(tag.persistentModelID)
      }
    }
  }
}

struct TagPicker_Previews: PreviewProvider {
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
    }

    func makeButtonStore(soundFont: SoundFont) -> StoreOf<SoundFontButtonFeature> {
      .init(
        initialState: .init(
          soundFontId: soundFont.persistentModelID,
          name: soundFont.displayName,
          presetCount: soundFont.presets.count,
          activeSoundFontId: SharedReader($activeSoundFontId),
          selectedSoundFontId: $selectedSoundFontId
        )
      ) {
        SoundFontButtonFeature()
      }
    }

    func makeButtonStore(index: Int) -> StoreOf<SoundFontButtonFeature> {
      makeButtonStore(soundFont: self.allSoundFonts[index])
    }

    func makeTagPickerStore() -> StoreOf<TagPickerFeature> {
      .init(
        initialState: .init(
          activeTagId: $activeTagId,
          allTagId: allTagId
        )
      ) {
        TagPickerFeature()
      }
    }
  }

  static var previewState = PreviewState()

  static var previews: some View {

    NavigationStack {
      List {
        ForEach(previewState.allSoundFonts) { soundFont in
          if soundFont.tagged(with: previewState.activeTagId) {
            SoundFontButtonView(store: previewState.makeButtonStore(soundFont: soundFont))
          }
        }
      }
      .navigationTitle("SoundFonts")
      .toolbar {
        ToolbarItemGroup {
          TagPickerView(store: previewState.makeTagPickerStore())
          Button(LocalizedStringKey("Add"),
                 systemImage: "plus",
                 action: {})
        }
      }
    }
    .modelContainer(modelContainer)
    .modelContext(modelContainer.mainContext)
  }
}
