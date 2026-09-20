import FeatureSupport
import SwiftUI

struct SettingsView: View {

  var body: some View {
    PageView(
      title: "Finally…",
      gist: "Here are some additional features available to you:"
    ) {
      Grid(alignment: .leadingFirstTextBaseline, verticalSpacing: 12) {
        GridRow {
          Text("•")
            .foregroundStyle(Color.alternateAccentColor)
          Text("Use as AUv3 components in supported audio apps like GarageBand and Cubasis")
            .gridColumnAlignment(.leading)
        }
        GridRow {
          Text("•")
            .foregroundStyle(Color.alternateAccentColor)
          Text("Use MIDI controllers to play notes and adjust settings")
            .gridColumnAlignment(.leading)
        }
        GridRow {
          Text("•")
            .foregroundStyle(Color.alternateAccentColor)
          Text("Connect using Bluetooth MIDI")
            .gridColumnAlignment(.leading)
        }
        GridRow {
          Text("•")
            .foregroundStyle(Color.alternateAccentColor)
          Text("Adjust the width of the virtual keyboard keys")
            .gridColumnAlignment(.leading)
        }
        GridRow {
          Text("•")
            .foregroundStyle(Color.alternateAccentColor)
          Text("Show solfège labels")
            .gridColumnAlignment(.leading)
        }
        GridRow {
          Text("•")
            .foregroundStyle(Color.alternateAccentColor)
          Text(
"""
Transpose pitch or set A4 frequency to values other than 440 Hz, either for a specific preset \
or globally.
"""
          )
          .gridColumnAlignment(.leading)
        }
      }
      .font(.body)
      Grid {
        GridRow {
          Image(systemName: .settingsButtonImageName)
            .imageScale(.large)
          Text("Tap to access these settings and more")
            .font(.body)
        }
      }
    }
    .foregroundStyle(.teal)
  }
}

#if DEBUG

#Preview {
  Preview(page: .settings)
}

#endif // DEBUG
