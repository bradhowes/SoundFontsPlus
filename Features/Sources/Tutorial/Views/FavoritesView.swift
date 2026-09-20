import FeatureSupport
import SwiftUI

struct FavoritesView: View {

  var body: some View {
    PageView(
      title: "Favorites",
      gist:
"""
Preset copies are known as \"favorites\". \
They provide a way to customize them without needing to edit the font file. They can be highlighted and arranged \
to be easily found in the presets list.
"""
    ) {
      VStack(spacing: 18) {
        PageViewImage(name: "PresetsList", width: 220)
        Text(
"""
A preset can have multiple copies, each with their own name and settings. \
They normally appear below the original preset, but you can change this in the \
\(Image(systemName: .settingsButtonImageName)) Settings panel.
"""
        )
      }
    }
  }
}

#if DEBUG

#Preview {
  Preview(page: .favorites)
}

#endif // DEBUG
