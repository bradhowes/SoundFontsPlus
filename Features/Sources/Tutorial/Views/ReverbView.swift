import FeatureSupport
import SwiftUI

struct ReverbView: View {

  var body: some View {
    PageView(
      title: "Reverb Controls",
      gist:
"""
You can add a reverberation effect to a preset and save its configuration so that it is restored when the preset activates. \
Tap the \(Image(systemName: .effectsButtonImageName)) toolbar button to show. \
Swipe up/down to change room or adjust knob value.
"""
    ) {
      Image("Reverb", bundle: Bundle.module)
        .resizable()
        .scaledToFit()
        .frame(width: 340)
        .shadow(
          color: .black,
          radius: CGFloat(6.0),
          x: CGFloat(0), y: CGFloat(0))
      Text("Controls")
        .foregroundStyle(Color.alternateAccentColor)
      Grid(verticalSpacing: 12) {
        GridRow {
          HStack {
            Image(systemName: .arrowDownButtonImageName)
            Text("On")
          }
          .gridColumnAlignment(.trailing)
          .foregroundStyle(.gray)
          Text("Toggle reverb effect")
            .gridColumnAlignment(.leading)
        }
        GridRow {
          HStack {
            Image(systemName: .arrowDownButtonImageName)
            Text("\(Image(systemName: .effectsLockButtonImageName))")
          }
          .foregroundStyle(.gray)
          Text("Keep settings when preset changes")
        }
        GridRow {
          Text("Room")
            .foregroundStyle(.gray)
          Text("Reverberation settings for different room types")
        }
        GridRow {
          Text("Amount")
            .foregroundStyle(.gray)
          Text("Level of the source audio vs. reverberated")
        }
      }
    }
  }
}

#if DEBUG

#Preview {
  Preview(page: .reverb)
}

#endif // DEBUG
