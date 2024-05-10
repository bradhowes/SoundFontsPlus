import SwiftData
import SwiftUI
import Models

struct SoundFontsListView: View {
  @Environment(\.modelContext) var modelContext: ModelContext
  @Query(sort: \Tag.name) private var tags: [Tag]

  @State private var soundFonts: [SoundFont] = []
  @Binding var selectedSoundFont: SoundFont?
  @Binding var activeSoundFont: SoundFont?
  @Binding var activePreset: Preset?
  @State private var activeTag: Tag?

  var body: some View {
    NavigationStack {
      VStack {
        List(soundFonts) { soundFont in
          SoundFontButtonView(soundFont: soundFont,
                              activeSoundFont: $activeSoundFont,
                              selectedSoundFont: $selectedSoundFont)
        }
        .navigationTitle("Fonts")
        List(tags) { tag in
          TagButtonView(tag: tag,
                        activeTag: $activeTag,
                        soundFonts: $soundFonts)
        }
      }.onAppear(perform: setInitialContent)
    }
  }

  @MainActor
  func setInitialContent() {
    let tag = activeTag ?? modelContext.ubiquitousTag(.all)
    activeTag = tag
    soundFonts = modelContext.soundFonts(with: tag)

    if activePreset == nil {
      activeSoundFont = soundFonts.dropFirst().first
      selectedSoundFont = activeSoundFont
      activePreset = activeSoundFont?.orderedPresets.dropFirst(40).first
    }
  }
}

