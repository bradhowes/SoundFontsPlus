// Copyright © 2025 Brad Howes. All rights reserved.

import ComposableArchitecture
import SwiftUI
import TagsFeature

/**
 The main view that shows the list of available SF2 files, and the list of presets for the active or selected
 SF2 file.
 */
public struct AppView: View {
  let store: StoreOf<TagsEditor>

  public init(store: StoreOf<TagsEditor>) {
    self.store = store
  }

  // private let store: StoreOf<MainViewFeature>

  public var body: some View {
    TagsEditorView(store: store)
//    Split(
//      primary: {
//        SoundFontListView(selectedSoundFont: store.selectedSoundFontId,
//                          activeSoundFont: store.activeSoundFontId,
//                          activePreset: store.activePresetId)
//      },
//      secondary: {
//        PresetListView(selectedSoundFont: $store.selectedSoundFont,
//                       activeSoundFont: $store.activeSoundFont,
//                       activePreset: $store.activePreset)
//      }
//    )
//    .splitter { Splitter(color: .accentColor, visibleThickness: 2) }
//    .constraints(minPFraction: 0.30, minSFraction: 0.30, priority: .primary)
//    .fraction(splitterPositionProvder)
  }

//  private var splitterPositionProvder: FractionHolder {
//    FractionHolder(getter: {
//      CGFloat(self.splitterPosition)
//    }, setter: {
//      self.splitterPosition = Double($0)
//    })
//  }
}
//
//struct MainView_Previews: PreviewProvider {
//  static var previews: some View {
//    AppView(store: )
//      .environment(\.modelContext, modelContainer.mainContext)
//  }
//}
