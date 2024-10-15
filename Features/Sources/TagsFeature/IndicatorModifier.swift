// Copyright © 2024 Brad Howes. All rights reserved.

import SwiftUI

public struct IndicatorModifier: ViewModifier {
  let shown: Bool

  private var indicatorWidth: CGFloat { 6 }
  private var cornerRadius: CGFloat { indicatorWidth / 2.0 }
  private var offset: CGFloat { -2.0 * indicatorWidth }
  private var indicator: Color { shown ? .indigo : .clear }
  private var labelColor: Color { shown ? .indigo : .blue }

  public func body(content: Content) -> some View {
    ZStack(alignment: .leading) {
      Rectangle()
        .fill(indicator.gradient)
        .frame(width: indicatorWidth)
        .cornerRadius(cornerRadius)
        .offset(x: offset)
        .animation(.linear(duration: 0.5), value: indicator)
      content
        .font(.headline)
        .foregroundStyle(labelColor)
        .animation(.linear(duration:0.5), value: labelColor)
    }
  }
}

extension View {
  public func indicator(_ shown: Bool) -> some View {
    modifier(IndicatorModifier(shown: shown))
  }
}
