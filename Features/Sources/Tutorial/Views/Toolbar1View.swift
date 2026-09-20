import FeatureSupport
import SwiftUI

struct Toolbar1View: View {

  var body: some View {
    PageView(
      title: "Toolbar",
      gist:
"""
Shows the active preset name, MIDI activity indicator, active voice count, and various conrols for accessing additional \
parts of the application.
"""
    ) {
      Image("ToolBar1", bundle: Bundle.module)
        .resizable()
        .scaledToFit()
        .shadow(
          color: .black,
          radius: CGFloat(6.0),
          x: CGFloat(0), y: CGFloat(0))
      Grid(verticalSpacing: 12) {
        GridRow {
          Image(systemName: .addSoundFontButtonImageName)
            .gridColumnAlignment(.trailing)
          Text("Add a new soundfont file")
            .gridColumnAlignment(.leading)
        }
        GridRow {
          Image(systemName: .tagsListButtonImageName)
            .gridColumnAlignment(.trailing)
          Text("Toggle tag list visibility")
        }
        GridRow {
          Image(systemName: .effectsButtonImageName)
            .gridColumnAlignment(.trailing)
          Text("Toggle effects panel visibility")
        }
        GridRow {
          Image(systemName: .moreButtonImageName)
            .gridColumnAlignment(.trailing)
          Text("Show more controls (in narrow views)")
        }
        GridRow {
          Image(systemName: .tapImageName)
            .gridColumnAlignment(.trailing)
          Text("Single-tap on the preset name to scroll to its entry.")
        }
        GridRow {
          HStack {
            Image(systemName: .tapImageName)
            Image(systemName: .tapImageName)
          }
          .gridColumnAlignment(.trailing)
          Text("Double-tap on the preset name to cancel all active notes in the synth (aka PANIC).")
        }
      }
    }
  }
}

#if DEBUG

#Preview {
  Preview(page: .toolbar1)
}

#endif // DEBUG
