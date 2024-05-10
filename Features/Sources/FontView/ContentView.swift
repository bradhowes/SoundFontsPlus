import ComposableArchitecture
import SwiftUI
import SwiftData
import SplitView
import Models

struct ContentView: View {
  @Environment(\.modelContext) private var modelContext: ModelContext

  @Query(sort: \Tag.name) private var tags: [Tag]

  // Not using @query since contents depend on activeTag
  @State private var soundFonts: [SoundFont] = []
  @State private var selectedSoundFont: SoundFont?
  @State private var activeSoundFont: SoundFont?
  @State private var activePreset: Preset?
  @State private var activeTag: Tag?
  @State private var searchText = ""

  // private let store: StoreOf<MainViewFeature>

  var body: some View {
    Split(
      primary: {
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
      },
      secondary: {
        NavigationStack {
          ScrollViewReader { proxy in
            List(selectedSoundFont?.orderedPresets ?? []) { preset in
              PresetButtonView(preset: preset,
                               selectedSoundFont: selectedSoundFont,
                               activeSoundFont: $activeSoundFont,
                               activePreset: $activePreset)
            }
            .searchable(text: $searchText)
            .onChange(of: selectedSoundFont) { _, newValue in
              selectedSoundFontChanged(newValue, proxy: proxy)
            }
          }.navigationTitle("Presets")
        }
      }
    )
    .splitter { Splitter(color: .accentColor, visibleThickness: 8) }
    .constraints(minPFraction: 0.15, minSFraction: 0.15, priority: .primary)
    .layout(LayoutHolder(.horizontal))
    .fraction(0.2)
    .border(.black)
    .padding([.leading, .trailing], 8)
  }
}

private extension ContentView {

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
  func selectedSoundFontChanged(_ newValue: SoundFont?, proxy: ScrollViewProxy) {
    // Delay the `scrollTo` until after the view has been populated with the new collection
    // of presets.
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
      withAnimation {
        let pos = newValue == activeSoundFont ? activePreset : selectedSoundFont?.orderedPresets.first
        proxy.scrollTo(pos)
      }
    }
  }
}

struct ContentView_Previews: PreviewProvider {
  static let modelContainer = VersionedModelContainer.make(isTemporary: true)
  static var previews: some View {
    ContentView()
      .environment(\.modelContext, modelContainer.mainContext)
  }
}
