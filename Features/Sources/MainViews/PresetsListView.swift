import SwiftData
import SwiftUI
import Models

/**
 Collection of preset buttons for the selected/active sound font.
 Supports searching based on preset name.
 */
struct PresetsListView: View {
  @Binding private var selectedSoundFont: SoundFont?
  @Binding private var activeSoundFont: SoundFont?
  @Binding private var activePreset: Preset?

  @State private var isPresented = false
  @State private var searchText = ""

  init(selectedSoundFont: Binding<SoundFont?>,
       activeSoundFont: Binding<SoundFont?>,
       activePreset: Binding<Preset?>) {
    self._selectedSoundFont = selectedSoundFont
    self._activeSoundFont = activeSoundFont
    self._activePreset = activePreset
  }

  var body: some View {
    NavigationStack {
      ScrollViewReader { proxy in
        List(selectedSoundFont?.orderedPresets ?? []) { preset in
          if searchText.isEmpty || preset.name.localizedStandardContains(searchText) {
            PresetButtonView(preset: preset,
                             selectedSoundFont: selectedSoundFont,
                             activeSoundFont: $activeSoundFont,
                             activePreset: $activePreset)
          }
        }
        .searchable(text: $searchText, isPresented: $isPresented, placement: .navigationBarDrawer, prompt: "Preset")
        .onChange(of: selectedSoundFont) { oldValue, newValue in
          if oldValue != newValue {
            scrollToActivePreset(proxy: proxy)
          }
        }
        .onChange(of: activePreset) { oldValue, newValue in
          if oldValue != newValue {
            scrollToActivePreset(proxy: proxy)
          }
        }
      }
      .navigationTitle("Presets")
      .toolbar {
        Button(LocalizedStringKey("Search"), systemImage: "magnifyingglass", action: { self.isPresented = true })
        }
    }
  }

  @MainActor
  func scrollToActivePreset(proxy: ScrollViewProxy) {
    // Delay the `scrollTo` until after the view has been populated with the new collection
    // of presets.
    let pos = selectedSoundFont == activeSoundFont ? (activePreset?.index ?? 0) : 0
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
      proxy.scrollTo(pos)
    }
  }
}

struct PresetListView_Previews: PreviewProvider {
  static let modelContainer = VersionedModelContainer.make(isTemporary: true)
  static var soundFonts: [SoundFont] { modelContainer.mainContext.soundFonts() }

  static var previews: some View {
    @State var selectedSoundFont: SoundFont? = soundFonts.dropFirst().first
    @State var activeSoundFont: SoundFont? = soundFonts.dropFirst().first
    @State var activePreset: Preset? = activeSoundFont?.orderedPresets.dropFirst(40).first

    PresetsListView(selectedSoundFont: $selectedSoundFont,
                    activeSoundFont: $activeSoundFont,
                    activePreset: $activePreset)
    .environment(\.modelContext, modelContainer.mainContext)
  }
}
