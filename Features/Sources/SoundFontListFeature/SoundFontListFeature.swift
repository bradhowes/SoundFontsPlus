import ComposableArchitecture
import SwiftUI
import Models

@Reducer
public struct SoundFontListFeature {

  //  @Reducer(state: .equatable)
  //  enum Path {
  //    case soundFontDetail(SoundFontDetail)
  //    case presetDetail(PresetDetail)
  //    case tagManager
  //  }

  @Dependency(\.modelContextProvider) var contextProvider

  @ObservableState
  public struct State: Equatable {
    // var path = StackState<Path.State>()

    var activeSoundFont: SoundFont
    var selectedSoundFont: SoundFont
    var activePreset: Preset

    public init(soundFont: SoundFont, preset: Preset) {
      activeSoundFont = soundFont
      selectedSoundFont = soundFont
      activePreset = preset
    }
  }

  enum Action {
    //    case path(StackActionOf<Path>)
    //    case soundFontList(SoundFontList.Action)
    //    case presetList(PresetList.Action)
    //    case addSoundFonts
    //    case removeSoundFont(SoundFont.ID)
    //    case editSoundFontInfo(SoundFont.ID)
    //    case hideSoundFont(SoundFont.ID)
    //    case editPresetInfo(Preset.ID)
  }

  var body: some ReducerOf<Self> {
    Reduce { state, action in
        .none
    }
  }
}
