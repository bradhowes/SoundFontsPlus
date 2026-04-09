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
    // Active favorite -- only for Preset buttons
    case activeFavorite
    // Active coloring but without an indicator image
    case activeNoIndicator
    // Favorite styling -- only for Preset buttons
    case favorite
    // Editing preset visibility
    case visibilityEditing

    func labelColor(colorScheme: ColorScheme) -> Color {
      switch self {
      case .none: return colorScheme == .dark ? .mainAccentColor.darker : .mainAccentColor.lighter
      case .active, .activeNoIndicator: return colorScheme == .dark ? .mainAccentColor.lighter : .mainAccentColor.darker
      case .activeFavorite: return colorScheme == .dark ? .alternateAccentColor.lighter : .alternateAccentColor.darker
      case .visibilityEditing, .favorite: return colorScheme == .dark ? .alternateAccentColor.darker : .alternateAccentColor.lighter
      case .selected: return .selected
      }
    }

    func indicatorColor(colorScheme: ColorScheme) -> Color {
      switch self {
      case .active: return colorScheme == .dark ? .mainAccentColor.lighter : .mainAccentColor.darker
      case .activeFavorite: return .alternateAccentColor
      default: return .clear
      }
    }

    func indicatorGradient(colorScheme: ColorScheme) -> Gradient {
      switch self {
      case .active, .activeFavorite: return .init(colors: [.clear, indicatorColor(colorScheme: colorScheme), .clear])
      default: return .init(colors: [.clear, .clear])
      }
    }
  }

  @Environment(\.colorScheme) private var colorScheme

  private let state: State
  private var indicatorWidth: CGFloat { 4 }
  private var cornerRadius: CGFloat { indicatorWidth / 2.0 }
  private var offset: CGFloat { -2.0 * indicatorWidth }
  private var indicator: Color { state.indicatorColor(colorScheme: colorScheme) }
  private var labelColor: Color { state.labelColor(colorScheme: colorScheme) }

  public init(state: State) {
    self.state = state
  }

  public func body(content: Content) -> some View {
    ZStack(alignment: .leading) {
      Rectangle()
        .fill(state.indicatorColor(colorScheme: colorScheme))
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
