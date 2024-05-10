import ComposableArchitecture
import SwiftUI
import SwiftData
import SplitView
import Models

struct ContentView: View {
  @State private var selectedSoundFont: SoundFont?
  @State private var activeSoundFont: SoundFont?
  @State private var activePreset: Preset?

  // private let store: StoreOf<MainViewFeature>

  var body: some View {
    Split(
      primary: {
        SoundFontsListView(selectedSoundFont: $selectedSoundFont,
                           activeSoundFont: $activeSoundFont,
                           activePreset: $activePreset)
      },
      secondary: {
        PresetsListView(selectedSoundFont: $selectedSoundFont,
                        activeSoundFont: $activeSoundFont,
                        activePreset: $activePreset)
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

struct ContentView_Previews: PreviewProvider {
  static let modelContainer = VersionedModelContainer.make(isTemporary: true)
  static var previews: some View {
    ContentView()
      .environment(\.modelContext, modelContainer.mainContext)
  }
}
