// Copyright © 2025 Brad Howes. All rights reserved.

import Theming

extension ThemeColorStyle {

  /// A style for primary labels
  static let primaryLabel: Self = Self(name: "primaryLabel")
  // Define additional styles as needed
}

extension Theme {

  static let `default`: Theme = .createDefaultTheme()
}

extension Theme {

  private static func createDefaultTheme() -> Theme {
    let colors: Theme.ColorMap = [
      .primaryLabel: ThemeColor(lightColor: .primary, darkColor: .primary)
    ]
    return Theme(name: "Default", colors: colors)
  }
}
