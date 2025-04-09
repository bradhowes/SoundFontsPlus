import SplitView
import SwiftUI

struct HandleDivider: SplitDivider {
  let layout: SplitLayout
  let styling: SplitStyling

  init(layout: SplitLayout, styling: SplitStyling) {
    self.layout = layout
    self.styling = styling
  }

  var body: some View {
    ZStack {
      switch layout {
      case .horizontal:

        Rectangle()
          .fill(Color(red: 0.08, green: 0.08, blue: 0.08))
          .frame(width: 10)
          .padding(0)

        RoundedRectangle(cornerRadius: styling.visibleThickness / 2)
          .fill(styling.color)
          .frame(width: styling.visibleThickness, height: 24)
          .padding(EdgeInsets(top: styling.inset, leading: 0, bottom: styling.inset, trailing: 0))

        VStack {
          Color.black
            .frame(width: 2, height: 2)
          Color.black
            .frame(width: 2, height: 2)
        }

      case .vertical:

        Rectangle()
          .fill(Color(red: 0.08, green: 0.08, blue: 0.08))
          .frame(height: 10)
          .padding(0)

        RoundedRectangle(cornerRadius: styling.visibleThickness / 2)
          .fill(styling.color)
          .frame(width: 24, height: styling.visibleThickness)
          .padding(EdgeInsets(top: 0, leading: styling.inset, bottom: 0, trailing: styling.inset))

        HStack {
          Color.black
            .frame(width: 2, height: 2)
          Color.black
            .frame(width: 2, height: 2)
        }
      }
    }
    .contentShape(Rectangle())
    //    .onTapGesture(count: 2) {
    //      print("double-tap")
    //      hide.hide(.secondary)
    //    }
  }
}
