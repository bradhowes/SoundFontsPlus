
import SwiftUI
import SwiftData
import SplitView
import Models


struct ContentView: View {
  @Query(sort: \SoundFont.displayName) var soundFonts: [SoundFont]

  @State private var selectedFont: SoundFont?
  @State private var activeFont: SoundFont?
  @State private var activePreset: Preset?

  private func soundFontColor(for soundFont: SoundFont) -> Color {
    if soundFont == activeFont { return .indigo }
    if soundFont == selectedFont { return .white }
    return .blue
  }

  var body: some View {
    Split(
      primary: {
        List(soundFonts) { soundFont in
          Button(action: { selectedFont = soundFont},
                 label: {
            Text(soundFont.displayName)
              .foregroundStyle(soundFontColor(for: soundFont))
          })
          .badge(soundFont.presets.count)
        }
        .onAppear {
          if activePreset == nil {
            activeFont = soundFonts.first
            selectedFont = activeFont
            activePreset = soundFonts.first?.orderedPresets.first
          }
        }
      },
      secondary: {
        ScrollViewReader { proxy in
          List(selectedFont?.orderedPresets ?? []) { preset in
            Button(action: {
              activeFont = selectedFont
              activePreset = preset
            }, label: {
              Text(preset.name)
                .foregroundStyle(activePreset == preset ? .indigo : .blue)
            }).id(preset)
          }
          .onChange(of: selectedFont) { _, newValue in
            if selectedFont == activeFont {
              withAnimation {
                proxy.scrollTo(activePreset)
              }
            } else {
              withAnimation {
                proxy.scrollTo(selectedFont?.orderedPresets.first, anchor: .top)
              }
            }
          }
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

struct ContentView_Previews: PreviewProvider {
  static let modelContainer = VersionedModelContainer.make(isTemporary: true)
  static var previews: some View {
    ContentView()
      .environment(\.modelContext, modelContainer.mainContext)
  }
}
