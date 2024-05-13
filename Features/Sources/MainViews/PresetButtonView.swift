// Copyright © 2024 Brad Howes. All rights reserved.

import SwiftUI
import Models

/**
 Custom Button view for a `Preset` model. Activating the button makes it the active preset.
 */
struct PresetButtonView: View {
  @Environment(\.dismissSearch) private var dismissSearch

  private let preset: Preset
  @State private var selectedSoundFont: SoundFont
  @Binding private var activeSoundFont: SoundFont
  @Binding private var activePreset: Preset

  init(preset: Preset, selectedSoundFont: SoundFont, activeSoundFont: Binding<SoundFont>,
       activePreset: Binding<Preset>) {
    self.preset = preset
    self.selectedSoundFont = selectedSoundFont
    self._activeSoundFont = activeSoundFont
    self._activePreset = activePreset
  }

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
    preset == activePreset ? .accentColor : .primary
  }
}
