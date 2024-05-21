// Copyright © 2024 Brad Howes. All rights reserved.

import SwiftData
import SwiftUI
import Models
import Dependencies

/**
 Custom Button view for a `Preset` model. Activating the button makes it the active preset.
 */
struct PresetButtonView: View {
  @Environment(\.dismissSearch) private var dismissSearch

  private let preset: Preset
  private let activePresetId: Preset.ID
  private let action: () -> Void

  init(preset: Preset, activePresetId: Preset.ID, action: @escaping () -> Void) {
    self.preset = preset
    self.activePresetId = activePresetId
    self.action = action
  }

  var body: some View {
    Button(action: action, label: {
      Text(preset.name)
        .foregroundStyle(labelColor)
    }).id(preset.persistentModelID)
  }

  var labelColor: Color {
    preset.persistentModelID == activePresetId ? .accentColor : .primary
  }
}
