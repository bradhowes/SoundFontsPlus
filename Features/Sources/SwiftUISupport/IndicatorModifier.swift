// Copyright © 2024 Brad Howes. All rights reserved.

import SwiftUI

public struct IndicatorModifier: ViewModifier {

  public enum State: CaseIterable {
    case none
    case selected
    case active

    var labelColor: Color {
      switch self {
      case .none: return .blue
      case .active: return .indigo
      case .selected: return .purple
      }
    }

    var indicatorColor: Color {
      switch self {
      case .none: return .clear
      case .active: return .indigo
      case .selected: return .clear
      }
    }
  }

  let state: State

  private var indicatorWidth: CGFloat { 6 }
  private var cornerRadius: CGFloat { indicatorWidth / 2.0 }
  private var offset: CGFloat { -2.0 * indicatorWidth }
  private var indicator: Color { state.indicatorColor }
  private var labelColor: Color { state.labelColor }

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

  public func indicator(_ state: IndicatorModifier.State) -> some View {
    modifier(IndicatorModifier(state: state))
  }

  public func indicator(_ shown: Bool) -> some View {
    modifier(IndicatorModifier(state: shown ? .active : .none))
  }
}
