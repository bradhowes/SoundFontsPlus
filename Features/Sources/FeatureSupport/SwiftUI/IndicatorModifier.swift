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

    case activeFavorite

    case activeNoIndicator

    case favorite

    var labelColor: Color {
      switch self {
      case .none: return .accentColor.darker
      case .active, .activeNoIndicator: return .accentColor.lighter
      case .activeFavorite: return .orange
      case .favorite: return .orange.darker
      case .selected: return .whiteText
      }
    }

    var indicatorColor: Color {
      switch self {
      case .none, .activeNoIndicator: return .clear
      case .active: return .accentColor.lighter
      case .activeFavorite: return .orange.lighter
      case .favorite: return .orange.darker
      case .selected: return .clear
      }
    }

    var indicatorGradient: Gradient {
      switch self {
      case .active, .activeFavorite: return .init(colors: [.clear, indicatorColor, .clear])
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
      content
        .font(.button)
        .foregroundStyle(labelColor)
    }
    .animation(.linear(duration: 0.3), value: indicator)
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

extension Color {
  fileprivate var darker: Self { self.mix(with: .black, by: 0.25) }
  fileprivate var lighter: Self { self.mix(with: .white, by: 0.30) }
}
