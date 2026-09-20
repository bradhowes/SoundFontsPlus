import FeatureSupport
import SwiftUI

struct PresetsView: View {

  var body: some View {
    PageView(
      title: "Presets",
      gist:
"""
The list to the right of the fonts list shows the visible presets in the selected font file.
"""
    ) {
      @Shared(.favoriteSymbolName) var symbolName
      HStack(alignment: .top, spacing: 16) {
        Image("PresetsList", bundle: Bundle.module)
          .resizable()
          .scaledToFit()
          .frame(width: 220)
          .shadow(
            color: .black,
            radius: CGFloat(6.0),
            x: CGFloat(0), y: CGFloat(0))
        VStack(alignment: .leading, spacing: 24) {
          Grid(verticalSpacing: 12) {
            GridRow {
              Text("•")
              Text("Tap to activate")
                .gridColumnAlignment(.leading)
            }
            GridRow {
              Text("•")
              Text("Long-tap to edit")
                .gridColumnAlignment(.leading)
            }
          }
        }
      }
      Text("Swipe Actions")
        .foregroundStyle(Color.alternateAccentColor)
      HStack(spacing: 22) {
        Grid {
          GridRow {
            Image(systemName: .editButtonImageName)
            Text("Edit preset")
              .gridColumnAlignment(.leading)
          }
          GridRow {
            Image(systemName: .favoriteButtonImageName)
              .foregroundStyle(Color.alternateAccentColor)
            Text("Create favorite")
              .gridColumnAlignment(.leading)
          }
        }
        Grid {
          GridRow {
            Image(systemName: .hidePresetButtonImageName)
              .foregroundStyle(.gray)
            Text("Hide preset")
              .gridColumnAlignment(.leading)
          }
          GridRow {
            Image(systemName: .deleteButtonImageName)
              .foregroundStyle(.red)
            Text("Remove favorite")
          }
        }
      }
      Text(
"""
Favorites you create will appear in gold and are prefixed with a \(Image(systemName: symbolName)) \
symbol (configurable). Next page talks more about them.
"""
      )
    }
  }
}

#if DEBUG

#Preview {
  Preview(page: .presets)
}

#endif // DEBUG
