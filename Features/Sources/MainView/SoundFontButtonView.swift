import SwiftUI
import Models

/**
 Custom Button view for a `SoundFont` model. Pressing it updates the collection of `Preset` models that are shown.
 */
struct SoundFontButtonView: View {
  let soundFont: SoundFont
  @Binding var activeSoundFont: SoundFont?
  @Binding var selectedSoundFont: SoundFont?

  var body: some View {
    Button(action: { 
      selectedSoundFont = soundFont
    }, label: {
      Text(soundFont.displayName)
        .foregroundStyle(labelColor)
    }).badge(soundFont.presets.count)
  }

  var labelColor: Color {
    if soundFont == activeSoundFont { return .accentColor }
    if soundFont == selectedSoundFont { return .secondary }
    return .primary
  }
}
