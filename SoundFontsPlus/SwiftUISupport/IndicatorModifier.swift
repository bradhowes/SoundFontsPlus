// Copyright © 2025 Brad Howes. All rights reserved.

import SwiftUI

public struct IndicatorModifier: ViewModifier {

  public enum State: CaseIterable {
    // No color change
    case none
    // Selected item -- only for SoundFont button when switching to a non-active item
    case selected
    // Active item -- shows the active SoundFont, Tag, or Preset
    case active

    case activeNoIndicator

    var labelColor: Color {
      switch self {
      case .none: return .whiteText
      case .active, .activeNoIndicator: return .accentColor
      case .selected: return .white
      }
    }

    var indicatorColor: Color {
      switch self {
      case .none, .activeNoIndicator: return .clear
      case .active: return .accentColor
      case .selected: return .clear
      }
    }

    var indicatorGradient: Gradient {
      switch self {
      case .active: return .init(colors: [.black, indicatorColor, .black])
      default: return .init(colors: [.clear, .clear])
      }
    }
  }

  let state: State

  private var indicatorWidth: CGFloat { 4 }
  private var cornerRadius: CGFloat { indicatorWidth / 2.0 }
  private var offset: CGFloat { -2.0 * indicatorWidth }
  private var indicator: Color { state.indicatorColor }
  private var labelColor: Color { state.labelColor }

  @Environment(\.editMode) private var editMode
  private var isEditing: Bool { editMode?.wrappedValue.isEditing ?? false }

  public func body(content: Content) -> some View {
    ZStack(alignment: .leading) {
      Rectangle()
        .fill(state.indicatorGradient)
        .frame(width: indicatorWidth)
        .cornerRadius(cornerRadius)
        .offset(x: offset)
        .animation(.linear(duration: isEditing ? 0.0 : 0.5), value: indicator)
      content
        .font(.button)
        .foregroundStyle(labelColor)
        .animation(.linear(duration: isEditing ? 0.0 : 0.5), value: labelColor)
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
