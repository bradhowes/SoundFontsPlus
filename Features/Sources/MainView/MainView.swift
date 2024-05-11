import ComposableArchitecture
import SwiftUI
import SwiftData
import SplitView
import Models

struct MainView: View {
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
    .splitter { Splitter(color: .accentColor, visibleThickness: 2) }
    .constraints(minPFraction: 0.30, minSFraction: 0.30, priority: .primary)
    .layout(LayoutHolder(.horizontal))
    .fraction(0.4)
  }
}

struct MainView_Previews: PreviewProvider {
  static let modelContainer = VersionedModelContainer.make(isTemporary: true)
  static var previews: some View {
    MainView()
      .environment(\.modelContext, modelContainer.mainContext)
  }
}
