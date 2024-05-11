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

  @Binding var selectedSoundFont: SoundFont?
  @Binding var activeSoundFont: SoundFont?
  @Binding var activePreset: Preset?

  @State private var soundFonts: [SoundFont] = []
  @State private var activeTag: Tag?
  @State private var activeTagName: String = "All"

  var body: some View {
    NavigationStack {
      List(soundFonts) { soundFont in
        SoundFontButtonView(soundFont: soundFont,
                            activeSoundFont: $activeSoundFont,
                            selectedSoundFont: $selectedSoundFont)
      }
      .navigationTitle("Fonts")
      .toolbar {
        pickerView()
        Button(LocalizedStringKey("Add"), systemImage: "plus", action: addSoundFont)
      }
    }.onAppear(perform: setInitialContent)
  }
}

fileprivate extension SoundFontsListView {

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

  @MainActor
  func pickerView() -> some View {
    Picker("Tag", selection: $activeTagName) {
      ForEach(tags) { tag in
        Text(tag.name)
          .tag(tag.name)
      }
    }.onChange(of: activeTagName) { oldValue, newValue in
      guard let tag = modelContext.findTag(name: newValue) else {
        fatalError("Unexpected nil value from fiindTag")
      }
      activeTag = tag
      withAnimation {
        soundFonts = modelContext.soundFonts(with: tag)
      }
    }
  }

  func addSoundFont() {

  }
}


struct SoundFontsListView_Previews: PreviewProvider {
  static let modelContainer = VersionedModelContainer.make(isTemporary: true)
  static var previews: some View {
    @State var selectedSoundFont: SoundFont?
    @State var activeSoundFont: SoundFont?
    @State var activePreset: Preset?

    SoundFontsListView(selectedSoundFont: $selectedSoundFont,
                       activeSoundFont: $activeSoundFont,
                       activePreset: $activePreset)
      .environment(\.modelContext, modelContainer.mainContext)
  }
}
