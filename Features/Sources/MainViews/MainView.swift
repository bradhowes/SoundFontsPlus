import ComposableArchitecture
import SwiftUI
import SwiftData
import SplitView
import Models

public extension String {
  static var splitterPosition: String { "splitterPosition" }
  static var activeSoundFont: String { "activeSoundFont" }
  static var activePreset: String { "activePreset" }
}

/**
 The main view that shows the list of available SF2 files, and the list of presets for the active or selected
 SF2 file.
 */
public struct MainView: View {
  @State private var selectedSoundFont: SoundFont
  @State private var activeSoundFont: SoundFont
  @State private var activePreset: Preset

  @Shared(.appStorage(.splitterPosition)) var splitterPosition = 0.4

  public init(activeSoundFont: SoundFont, activePreset: Preset) {
    self.selectedSoundFont = activeSoundFont
    self.activeSoundFont = activeSoundFont
    self.activePreset = activePreset
  }

  // private let store: StoreOf<MainViewFeature>

  public var body: some View {
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
    .fraction(splitterPositionProvder)
  }

  private var splitterPositionProvder: FractionHolder {
    FractionHolder(getter: {
      CGFloat(self.splitterPosition)
    }, setter: {
      self.splitterPosition = Double($0)
    })
  }
}

struct MainView_Previews: PreviewProvider {
  static let modelContainer = VersionedModelContainer.make(isTemporary: true)
  static var previews: some View {
    let soundFont = modelContainer.mainContext.soundFonts()[0]

    MainView(activeSoundFont: soundFont, activePreset: soundFont.orderedPresets[0])
      .environment(\.modelContext, modelContainer.mainContext)
  }
}
