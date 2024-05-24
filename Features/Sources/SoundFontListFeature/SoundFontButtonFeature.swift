// Copyright © 2024 Brad Howes. All rights reserved.

import ComposableArchitecture
import SwiftData
import SwiftUI
import Models

/**
 Custom Button view for a `SoundFont` model. Pressing it updates the collection of `Preset` models that are shown.
 */

@Reducer
struct SoundFontButtonFeature: Reducer {

  @ObservableState
  struct State: Equatable {
    var soundFontId: SoundFont.ID
    var name: String
    var presetCount: Int

    @SharedReader var activeSoundFontId: SoundFont.ID
    @Shared var selectedSoundFontId: SoundFont.ID

    var nameColor: Color {
      if soundFontId == activeSoundFontId { return .accentColor }
      if soundFontId == selectedSoundFontId { return .secondary }
      return .primary
    }
  }

  public enum Action {
    case buttonTapped
  }

  public var body: some ReducerOf<Self> {
    Reduce<State, Action> { state, action in
      switch action {
      case .buttonTapped:
        state.selectedSoundFontId = state.soundFontId
        return .none
      }
    }
  }
}

struct SoundFontButtonView: View {
  private var store: StoreOf<SoundFontButtonFeature>

  init(store: StoreOf<SoundFontButtonFeature>) {
    self.store = store
  }

  public var body: some View {
    Button(action: { store.send(.buttonTapped) }, label: {
      Text(store.name)
        .foregroundStyle(store.nameColor)
    }).badge(Text("\(store.presetCount)")
      .font(.caption))
  }
}

struct SoundFontButton_Previews: PreviewProvider {
  static let modelContainer = VersionedModelContainer.make(isTemporary: true)

  @MainActor
  struct PreviewState {
    let soundFonts: [SoundFont]
    let activeSoundFont: SoundFont
    let selectedSoundFont: SoundFont
    let otherSoundFont: SoundFont

    @Shared var activeSoundFontId: SoundFont.ID
    @Shared var selectedSoundFontId: SoundFont.ID

    init() {
      let soundFonts = modelContainer.mainContext.allSoundFonts()

      self.soundFonts = soundFonts
      self.activeSoundFont = soundFonts[0]
      self.selectedSoundFont = soundFonts[1]
      self.otherSoundFont = soundFonts[2]

      _activeSoundFontId = Shared(soundFonts[0].persistentModelID)
      _selectedSoundFontId = Shared(soundFonts[1].persistentModelID)
    }

    func makeStore(index: Int) -> StoreOf<SoundFontButtonFeature> {
      .init(initialState:
          .init(
            soundFontId: soundFonts[index].persistentModelID,
            name: soundFonts[index].displayName,
            presetCount: soundFonts[index].presets.count,
            activeSoundFontId: SharedReader($activeSoundFontId),
            selectedSoundFontId: $selectedSoundFontId
          )) {
            SoundFontButtonFeature()
          }
    }
  }

  static var previewState = PreviewState()

  static var previews: some View {
    List {
      SoundFontButtonView(store: previewState.makeStore(index: 0))
      SoundFontButtonView(store: previewState.makeStore(index: 1))
      SoundFontButtonView(store: previewState.makeStore(index: 2))
    }
    .modelContainer(modelContainer)
    .modelContext(modelContainer.mainContext)
  }
}
