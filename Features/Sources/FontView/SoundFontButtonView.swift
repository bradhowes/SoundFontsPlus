import SwiftUI
import Models

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
    if soundFont == activeSoundFont { return .indigo }
    if soundFont == selectedSoundFont { return .white }
    return .blue
  }
}
