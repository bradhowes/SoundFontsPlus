import ComposableArchitecture
import SwiftUI
import SwiftData
import SplitView
import Models


@MainActor
struct ContentView: View {
  @Environment(\.modelContext) private var modelContext: ModelContext

  @Query(sort: \Tag.name) private var tags: [Tag]

  // Not using @query since contents depend on activeTag
  @State private var soundFonts: [SoundFont]

  @State private var selectedFont: SoundFont?
  @State private var activeFont: SoundFont?
  @State private var activePreset: Preset?
  @State private var activeTag: Tag?
  @State private var searchText = ""

  init() {
    soundFonts = []
  }

  // private let store: StoreOf<MainViewFeature>

  var body: some View {
    Split(
      primary: {
        NavigationStack {
          VStack {
            List(soundFonts) { soundFont in
              soundFontButton(soundFont)
            }
            .navigationTitle("Fonts")
            List(tags) { tag in
              tagButton(tag)
            }
            .navigationTitle("Tags")
          }.onAppear(perform: setInitialContent)
        }
      },
      secondary: {
        NavigationStack {
          ScrollViewReader { proxy in
            List(selectedFont?.orderedPresets ?? []) {
              presetButton($0)
            }
            .searchable(text: $searchText)
            .onChange(of: selectedFont) { _, newValue in
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

  func soundFontButton(_ soundFont: SoundFont) -> some View {
    Button(action: { setSelectedSoundFont(soundFont) },
           label: { soundFontLabel(soundFont) } )
    .badge(soundFont.presets.count)
  }

  func soundFontLabel(_ soundFont: SoundFont) -> some View {
    Text(soundFont.displayName)
      .foregroundStyle(soundFontColor(for: soundFont))
  }

  func soundFontColor(for soundFont: SoundFont) -> Color {
    if soundFont == activeFont { return .indigo }
    if soundFont == selectedFont { return .white }
    return .blue
  }

  func setSelectedSoundFont(_ soundFont: SoundFont) {
    selectedFont = soundFont
  }

  @MainActor
  func setInitialContent() {
    let tag = activeTag ?? modelContext.ubiquitousTag(.all)
    activeTag = tag
    soundFonts = modelContext.soundFonts(with: tag)

    if activePreset == nil {
      activeFont = soundFonts.dropFirst().first
      selectedFont = activeFont
      activePreset = activeFont?.orderedPresets.dropFirst(40).first
    }
  }

  func presetButton(_ preset: Preset) -> some View {
    Button(action: { presetButtonTapped(preset) }, label: { presetButtonLabel(preset) } )
      .id(preset)
  }

  func presetButtonLabel(_ preset: Preset) -> some View {
    Text(preset.name)
      .foregroundStyle(activePreset == preset ? .indigo : .blue)
  }

  func selectedSoundFontChanged(_ newValue: SoundFont?, proxy: ScrollViewProxy) {
    if newValue == activeFont {
      withAnimation {
        proxy.scrollTo(activePreset)
      }
    } else {
      withAnimation {
        proxy.scrollTo(selectedFont?.orderedPresets.first, anchor: .top)
      }
    }
  }

  func presetButtonTapped(_ preset: Preset) {
    activeFont = selectedFont
    activePreset = preset
  }

  @MainActor
  func tagButton(_ tag: Tag) -> some View {
    Button(action: { tagButtonTapped(tag) }, label: { tagButtonLabel(tag) })
  }

  func tagButtonLabel(_ tag: Tag) -> some View {
    Text(tag.name).foregroundStyle(activeTag == tag ? .indigo : .blue)
  }

  func tagButtonTapped(_ tag: Tag) {
    activeTag = tag
    soundFonts = modelContext.soundFonts(with: tag)
  }
}

struct ContentView_Previews: PreviewProvider {
  static let modelContainer = VersionedModelContainer.make(isTemporary: true)
  static var previews: some View {
    ContentView()
      .environment(\.modelContext, modelContainer.mainContext)
  }
}
