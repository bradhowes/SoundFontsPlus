import Foundation
import SwiftData
import SwiftUI

import Models

/**
 Shows a list of SoundFont entities that all have the current active Tag entity
 */
struct TagFilteredSoundFontListView: View {
  @Query private var soundFonts: [SoundFont]

  @Binding private var activeSoundFont: SoundFont
  @Binding private var selectedSoundFont: SoundFont
  @Binding private var activePreset: Preset

  /**
   Set properties for the view.

   - parameter tag: the tag to filter with
   - parameter activeSoundFont: bindings to the active SoundFont of the parent
   - parameter selectedSoundFont: bindings to the selected SoundFont of the parent
   - parameter activePreset: bindings to the active Preset of the parent
   */
  init(tag: Tag?, activeSoundFont: Binding<SoundFont>, selectedSoundFont: Binding<SoundFont>,
       activePreset: Binding<Preset>) {
    self._activeSoundFont = activeSoundFont
    self._selectedSoundFont = selectedSoundFont
    self._activePreset = activePreset
    _soundFonts = Query(SoundFont.fetchDescriptor(by: tag), animation: .default)
  }

  var body: some View {
    List(soundFonts) { soundFont in
      SoundFontButtonView(soundFont: soundFont,
                          activeSoundFont: $activeSoundFont,
                          selectedSoundFont: $selectedSoundFont)
    }
    // .onAppear(perform: setInitialContent)
  }

  @MainActor
  func setInitialContent() {
//
//    // TODO: restore these from persistent storage
//    if activePreset == nil {
//      activeSoundFont = soundFonts.dropFirst().first
//      selectedSoundFont = activeSoundFont
//      activePreset = activeSoundFont?.orderedPresets.first
//    }
  }
}
