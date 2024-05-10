import SwiftUI
import Models

struct PresetButtonView: View {
  let preset: Preset
  @State var selectedSoundFont: SoundFont?
  @Binding var activeSoundFont: SoundFont?
  @Binding var activePreset: Preset?

  var body: some View {
    Button(action: {
      activePreset = preset
      activeSoundFont = selectedSoundFont
    }, label: {
      Text(preset.name)
        .foregroundStyle(activePreset == preset ? .indigo : .blue)
    }).id(preset)
  }
}
