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

struct PresetList: View {
  private var presets: [Preset]

  init(soundFont: SoundFont) {
    presets = soundFont.presets.sorted(using: KeyPathComparator(\Preset.index))
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
  let config = ModelConfiguration(isStoredInMemoryOnly: true)
  let container = try! ModelContainer(for: SoundFont.self, configurations: config)
  do {
    let soundFont = try container.mainContext.createSoundFont(resourceTag: .freeFont)
    _ = try container.mainContext.createSoundFont(resourceTag: .museScore)
    _ = try container.mainContext.createSoundFont(resourceTag: .rolandNicePiano)
    return PresetsView(soundFont: soundFont)
      .modelContainer(container)
  } catch {
    fatalError("Failed to create preview data")
  }
}
