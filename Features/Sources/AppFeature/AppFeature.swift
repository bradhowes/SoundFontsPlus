import ComposableArchitecture
import SwiftUI
import Models
import SwiftData
import SoundFontListFeature
import PresetListFeature


@Reducer
public struct AppFeature {

  @Reducer(state: .equatable)
  enum Path {
    case soundFontDetail
    case presetDetail
  }

  @Dependency(\.modelContextProvider) var contextProvider

  @ObservableState
  public struct State: Equatable {
    @Shared(.activePreset) var activePreset: Preset.ID? = nil
    @Shared(.selectedSoundFont) var selectedSoundFont: SoundFont.ID? = nil
  }

  enum Action {
    case path(StackActionOf<Path>)
    // case soundFontList(SoundFontListFeature.Action)
    case presetList(PresetListFeature.Action)
  }

  var body: some ReducerOf<Self> {
    Reduce { state, action in
      .none
    }
  }
}
