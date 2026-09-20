import FeatureSupport
import SwiftUI

struct Toolbar2View: View {

  var body: some View {
    PageView(
      title: "More Controls",
      gist:
"""
Change the visible key range with the \(.shiftKeyboardLeftIndicator) and \(.shiftKeyboardRightIndicator) buttons. \
You can have a preset/favorite adjust the keyboard when it becomes active. \
Tap \(Image(systemName: .fixedKeyboardButtonImageName)) to toggle keyboard sliding during playing.
"""
    ) {
      PageViewImage(name: "ToolBar2", height: 60)
      Grid(verticalSpacing: 12) {
        GridRow {
          Image(systemName: .settingsButtonImageName)
          Text("Show application settings panel")
            .gridColumnAlignment(.leading)
        }
        GridRow {
          Image(systemName: .presetsVisibilityButtonImageName)
          Text("Change visibility of presets")
        }
        GridRow {
          Image(systemName: .helpButtonImageName)
          Text("Show quick-help guide")
        }
        GridRow {
          Image(systemName: .moreButtonImageName)
            .foregroundStyle(Color.alternateAccentColor)
          Text("Show/hide these buttons in narrow views")
        }
      }
    }
  }
}

#if DEBUG

#Preview {
  Preview(page: .toolbar2)
}

#endif // DEBUG
