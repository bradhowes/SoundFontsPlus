import SwiftData
import SwiftUI
import Models

/**
 Collection of SoundFont model buttons. Activating a button will show the presets associated with the SoundFont, but
 will not change the active preset.
 */
struct SoundFontsListView: View {
  @Environment(\.modelContext) var modelContext: ModelContext
  @Query(sort: \Tag.name) private var tags: [Tag]

  @Binding var selectedSoundFont: SoundFont
  @Binding var activeSoundFont: SoundFont
  @Binding var activePreset: Preset

  // @State private var soundFonts: [SoundFont] = []
  @State private var activeTag: Tag?
  @State private var addSoundFont: Bool = false

  var body: some View {
    NavigationStack {
      TagFilteredSoundFontListView(tag: activeTag, activeSoundFont: $activeSoundFont, selectedSoundFont: $selectedSoundFont,
                      activePreset: $activePreset)
      .navigationTitle("Files")
      .toolbar {
        TagPickerView(activeTag: $activeTag)
        Button(LocalizedStringKey("Add"), systemImage: "plus", action: { addSoundFont = true })
      }
    }
    .sheet(isPresented: $addSoundFont) {
      SF2Picker(showingPicker: $addSoundFont)
    }
  }
}

fileprivate extension SoundFontsListView {

  @MainActor
  func setInitialContent() {
    let tag = activeTag ?? modelContext.ubiquitousTag(.all)
    activeTag = tag
  }
}

struct SoundFontsListView_Previews: PreviewProvider {
  static let modelContainer = VersionedModelContainer.make(isTemporary: true)
  static var previews: some View {
    let soundFont = modelContainer.mainContext.soundFonts()[0]

    @State var selectedSoundFont: SoundFont = soundFont
    @State var activeSoundFont: SoundFont = soundFont
    @State var activePreset: Preset = soundFont.orderedPresets[0]

    SoundFontsListView(selectedSoundFont: $selectedSoundFont,
                       activeSoundFont: $activeSoundFont,
                       activePreset: $activePreset)
      .environment(\.modelContext, modelContainer.mainContext)
  }
}
