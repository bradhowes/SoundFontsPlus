import SwiftUI
import Models

struct PresetButtonView: View {
  @Environment(\.dismissSearch) private var dismissSearch

  let preset: Preset
  @State var selectedSoundFont: SoundFont?
  @Binding var activeSoundFont: SoundFont?
  @Binding var activePreset: Preset?

  var body: some View {
    Button(action: {
      activePreset = preset
      activeSoundFont = selectedSoundFont
      dismissSearch()
    }, label: {
      Text(preset.name)
        .foregroundStyle(labelColor)
    }).id(preset.index)
  }

  var labelColor: Color {
    preset == activePreset ? .indigo : .blue
  }
}
