import SwiftData
import SwiftUI

import Models

struct PresetsView: View {
  let soundFont: SoundFont

  init(soundFont: SoundFont) {
    self.soundFont = soundFont
  }

  var body: some View {
    NavigationView {
      PresetList(soundFont: soundFont)
        .navigationTitle("Font \(soundFont.displayName)")
    }
  }
}

@MainActor
struct PresetList: View {
  @Environment(\.modelContext) var modelContext
  private var presets: [Preset] = []

  init(soundFont: SoundFont) {
    self.presets = modelContext.orderedPresets(for: soundFont)
  }

  var body: some View {
    List {
      ForEach(presets) { preset in
        Text(preset.name)
      }
    }
  }
}

#Preview {
  let container = VersionedModelContainer.make(isTemporary: true)
  let soundFont = container.mainContext.soundFonts()[0]
  return PresetsView(soundFont: soundFont)
    .modelContainer(container)
}
