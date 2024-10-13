// Copyright © 2024 Brad Howes. All rights reserved.

import Models
import SwiftData
import SwiftUI

/**
 Custom Button view for a `Preset` model. Activating the button makes it the active preset.
 */
struct PresetButtonView: View {
  @Environment(\.dismissSearch) private var dismissSearch

  private let preset: PresetModel
  // private let activePresetId: PresetModel.ID
  private let action: () -> Void

  init(preset: PresetModel, action: @escaping () -> Void) {
    self.preset = preset
    self.action = action
  }

  var body: some View {
    Button(action: action, label: {
      Text(preset.displayName)
        .foregroundStyle(labelColor)
    }).id(preset.persistentModelID)
  }

  var labelColor: Color {
    preset.persistentModelID == activePresetId ? .accentColor : .primary
  }
}
