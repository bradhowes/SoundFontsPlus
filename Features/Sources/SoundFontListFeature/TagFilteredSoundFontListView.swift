// Copyright © 2024 Brad Howes. All rights reserved.

import ComposableArchitecture
import Foundation
import Models
import SwiftData
import SwiftUI


@Reducer
struct TagFilteredSoundFontListFeature {

  @ObservableState
  struct State: Equatable {
    @Shared var selectedSoundFontId: SoundFont.ID
    @SharedReader var activeSoundFontId: SoundFont.ID
    @SharedReader var activePresetId: Preset.ID

    var tagPicker: TagPickerFeature.State

    var pendingDeletion: SoundFont?
    var confirmDeletion: Bool = false
  }

  enum Action: BindableAction {
    case binding(BindingAction<State>)
    case soundFontButtonTapped(soundFontId: SoundFont.ID)
    case deleteSwiped(soundFontId: SoundFont.ID)
    case editSwiped(soundFontId: SoundFont.ID)
    case showAll
  }

  var body: some ReducerOf<Self> {
    BindingReducer()
    Reduce { state, action in
      switch action {
      case let .soundFontButtonTapped(soundFontId):
        state.selectedSoundFontId = soundFontId
        return .none
      case let .deleteSwiped(soundFontId):
        deleteSoundFont(state: &state, soundFontId: soundFontId)
        return .none
      case let .editSwiped(soundFontId):
        editSoundFont(state: &state, soundFontId: soundFontId)
        return .none
      case .binding:
        return .none
      case .showAll:
        return TagPickerFeature().reduce(into: &state.tagPicker, action: .showAll)
          .map { _ in Action.showAll }
      }
    }
  }

  func deleteSoundFont(state: inout State, soundFontId: SoundFont.ID) {
  }

  func editSoundFont(state: inout State, soundFontId: SoundFont.ID) {
  }
}

struct TagFilteredSoundFontListView: View {
  @Environment(\.modelContext) var modelContext
  @Query(sort: \SoundFont.displayName) private var soundFonts: [SoundFont]

  @Bindable private var store: StoreOf<TagFilteredSoundFontListFeature>

  init(store: StoreOf<TagFilteredSoundFontListFeature>) {
    self.store = store
  }

  public var body: some View {
    List {
      ForEach(soundFonts) { soundFont in
        if soundFont.tagged(with: store.tagPicker.activeTagId) {
          SoundFontButtonView(store: makeButtonStore(soundFont: soundFont))
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
              if !soundFont.location.isBuiltin {
                Button(role: .destructive) {
                  store.send(.deleteSwiped(soundFontId: soundFont.persistentModelID))
                } label: {
                  Label("Delete", systemImage: "trash.fill")
                }
              }
              Button(role: .none) {
                store.send(.editSwiped(soundFontId: soundFont.persistentModelID))
              } label: {
                Label("Edit", systemImage: "pencil")
              }
            }
        }
      }
    }.animation(.default)

    //      .alert("Confirm Deletion", isPresented: $confirmDeletion) {
    //      Button(role: .destructive) {
    //        delete(soundFont: pendingDeletion!)
    //        confirmDeletion = false
    //      } label: {
    //        Text("Delete")
    //      }
    //      Button(role: .cancel) {
    //        pendingDeletion = nil
    //        confirmDeletion = false
    //      } label: {
    //        Text("Cancel")
    //      }
    //    } message: {
    //      let name = pendingDeletion?.displayName ?? "???"
    //      Text("Really delete \(name)? This cannot be undone.")
    //    }
  }

  private func makeButtonStore(soundFont: SoundFont) -> StoreOf<SoundFontButtonFeature> {
    .init(
      initialState: .init(
        soundFontId: soundFont.persistentModelID,
        name: soundFont.displayName,
        presetCount: soundFont.presets.count,
        activeSoundFontId: store.$activeSoundFontId,
        selectedSoundFontId: store.$selectedSoundFontId
      )
    ) {
      SoundFontButtonFeature()
    }
  }

  //  @MainActor
  //  private func delete(soundFont: SoundFont) {
  //    let deletingActiveSoundFont = soundFont.persistentModelID == activeSoundFontId
  //    let deletingSelectedSoundFont = soundFont.persistentModelID == selectedSoundFontId
  //
  //    modelContext.delete(soundFont: soundFont)
  //
  //    try! modelContext.save()
  //
  //    if deletingActiveSoundFont {
  //      let soundFont = modelContext.allSoundFonts()[0]
  //      activeSoundFontId = soundFont.persistentModelID
  //      activePresetId = soundFont.orderedPresets[0].persistentModelID
  //    }
  //
  //    if deletingSelectedSoundFont {
  //      selectedSoundFontId = activeSoundFontId
  //    }
  //  }
}

struct TagFilteredSoundFontList_Previews: PreviewProvider {
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

    func makeStore() -> StoreOf<TagFilteredSoundFontListFeature> {
      .init(
        initialState: .init(
          selectedSoundFontId: $selectedSoundFontId,
          activeSoundFontId: SharedReader($activeSoundFontId),
          activePresetId: SharedReader($activePresetId),
          tagPicker: makeTagPickerState()
        )
      ) {
        TagFilteredSoundFontListFeature()
      }
    }

    func makeTagPickerState() -> TagPickerFeature.State { 
      .init(activeTagId: $activeTagId, allTagId: allTagId) }
  }

  static var previewState = PreviewState()
  static var store = previewState.makeStore()

  static var previews: some View {

    NavigationStack {
      TagFilteredSoundFontListView(store: store)
        .navigationTitle("SoundFonts")
        .toolbar {
          ToolbarItemGroup {
            TagPickerView(store: Store(
              initialState: .init(
                activeTagId: store.tagPicker.$activeTagId, 
                allTagId: store.tagPicker.allTagId)) {
                  TagPickerFeature()
                })
            Button(LocalizedStringKey("Add"),
                   systemImage: "plus",
                   action: {})
          }
        }
    }
    .onTapGesture(count: 2) {
      store.send(.showAll)
    }
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
