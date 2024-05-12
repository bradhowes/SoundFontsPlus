import SwiftUI
import Models

/**
 Custom Button view for a `SoundFont` model. Pressing it updates the collection of `Preset` models that are shown.
 */
struct SoundFontButtonView: View {
  let soundFont: SoundFont
  @Binding var activeSoundFont: SoundFont
  @Binding var selectedSoundFont: SoundFont

  var body: some View {
    Button(action: { 
      selectedSoundFont = soundFont
    }, label: {
      Text(soundFont.displayName)
        .foregroundStyle(labelColor)
    }).badge(Text("\(soundFont.presets.count)")
      .font(.caption))
  }

  var labelColor: Color {
    if soundFont == activeSoundFont { return .accentColor }
    if soundFont == selectedSoundFont { return .secondary }
    return .primary
  }
}

struct SoundFontButton_Previews: PreviewProvider {
  static let modelContainer = VersionedModelContainer.make(isTemporary: true)
  static var previews: some View {
    let soundFont = modelContainer.mainContext.soundFonts()[0]
    @State var activeSoundFont: SoundFont = soundFont
    @State var selectedSoundFont: SoundFont = soundFont
    List {
      SoundFontButtonView(soundFont: soundFont, activeSoundFont: $activeSoundFont, selectedSoundFont: $selectedSoundFont)
    }
    .environment(\.modelContext, modelContainer.mainContext)
  }
}
