import FeatureSupport
import SwiftUI

struct FontsView: View {

  var body: some View {
    PageView(
      title: "Fonts",
      gist:
"""
The panel on the left-hand side shows names of the installed soundfont files.
"""
    ) {
      HStack(alignment: .top, spacing: 16) {
        Image("FontsList", bundle: Bundle.module)
          .resizable()
          .scaledToFit()
          .frame(width: 140)
          .shadow(
            color: .black,
            radius: CGFloat(6.0),
            x: CGFloat(0), y: CGFloat(0))

        VStack(alignment: .leading, spacing: 24) {
          Grid(verticalSpacing: 12) {
            GridRow {
              Text("•")
              Text("Tap to activate and view the presets")
                .gridColumnAlignment(.leading)
            }
            GridRow {
              Text("•")
              Text("Long-tap to show editor panel")
                .gridColumnAlignment(.leading)
            }
            Text("Swipe Actions")
              .foregroundStyle(Color.alternateAccentColor)
            GridRow {
              Image(systemName: .editButtonImageName)
              Text("Edit name and tags")
                .gridColumnAlignment(.leading)
            }
            GridRow {
              Image(systemName: .deleteButtonImageName)
                .foregroundStyle(.red)
              Text("Remove from device")
                .gridColumnAlignment(.leading)
            }
          }
        }
      }
      Text(
      """
Tap the \(Image(systemName: .addSoundFontButtonImageName)) toolbar button \
to add new files from iCloud or an external disk.
"""
      )
    }
  }
}

#if DEBUG

#Preview {
  Preview(page: .fonts)
}

#endif // DEBUG
