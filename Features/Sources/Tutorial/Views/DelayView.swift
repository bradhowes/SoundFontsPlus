import FeatureSupport
import SwiftUI

struct DelayView: View {

  var body: some View {
    PageView(
      title: "Delay Controls",
      gist:
"""
You can also add a delay effect to a preset's audio output. Swipe up/down on knob or \
tap on label to enter numeric value.
"""
    ) {
      PageViewImage(name: "Delay", width: 340)
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
          Text("Time")
            .foregroundStyle(.gray)
          Text("Delay before replaying source audio")
        }
        GridRow {
          Text("Feedback")
            .foregroundStyle(.gray)
          Text("Level and phase of repeated audio")
        }
        GridRow {
          Text("Cutoff")
            .foregroundStyle(.gray)
          Text("Low-pass filter applied to delayed audio")
        }
        GridRow {
          Text("Amount")
            .foregroundStyle(.gray)
          Text("Level of the source audio vs. delayed")
        }
      }
    }
  }
}

#if DEBUG

#Preview {
  Preview(page: .delay)
}

#endif // DEBUG
