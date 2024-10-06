// Copyright © 2024 Brad Howes. All rights reserved.

import ComposableArchitecture
import SwiftUI
import SwiftData
import SplitView
import Models
import SoundFontListFeature
import PresetListFeature


public extension String {
  static var splitterPositionKey: String { "splitterPosition" }
  static var activeSoundFontKey: String { "activeSoundFont" }
  static var activePresetKey: String { "activePreset" }
}

/**
 The main view that shows the list of available SF2 files, and the list of presets for the active or selected
 SF2 file.
 */
public struct AppView: View {
  let store: StoreOf<AppFeature>

  @Shared(.appStorage(.splitterPositionKey)) var splitterPosition = 0.4

  public init(store: StoreOf<AppFeature>) {
    self.store = store
  }

  // private let store: StoreOf<MainViewFeature>

  public var body: some View {
    Split(
      primary: {
        SoundFontListView(selectedSoundFont: store.selectedSoundFontId,
                          activeSoundFont: store.activeSoundFontId,
                          activePreset: store.activePresetId)
      },
      secondary: {
        PresetListView(selectedSoundFont: $store.selectedSoundFont,
                       activeSoundFont: $store.activeSoundFont,
                       activePreset: $store.activePreset)
      }
    )
    .splitter { Splitter(color: .accentColor, visibleThickness: 2) }
    .constraints(minPFraction: 0.30, minSFraction: 0.30, priority: .primary)
    .fraction(splitterPositionProvder)
  }

  private var splitterPositionProvder: FractionHolder {
    FractionHolder(getter: {
      CGFloat(self.splitterPosition)
    }, setter: {
      self.splitterPosition = Double($0)
    })
  }
}

struct MainView_Previews: PreviewProvider {
  static let modelContainer = VersionedModelContainer.make(isTemporary: true)
  static var previews: some View {
    let soundFont = modelContainer.mainContext.allSoundFonts()[0]

    AppView(activeSoundFont: soundFont, activePreset: soundFont.orderedPresets[0])
      .environment(\.modelContext, modelContainer.mainContext)
  }
}
