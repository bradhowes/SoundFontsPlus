// Copyright © 2025 Brad Howes. All rights reserved.

import SwiftUI

/**
 Setting that controls how the app will apply a color scheme.

 - `system` -- the app will use the `@Environment(\.colorScheme)` value provided by the operating system
 - `light` -- the app will always appear in light mode regardless of operating system setting
 - `dark` -- the app will always appear in dark mode regardless of operating system setting
 */
@frozen
public enum ColorSchemeBehavior: String, CaseIterable, Identifiable {
  case system = "Device"
  case light = "Light"
  case dark = "Dark"

  public var id: Self { self }

  /// - returns: the value to use in ``View.preferredColorScheme``
  public var preferredColorScheme: ColorScheme? {
    switch self {
    case .system: return nil
    case .light: return .light
    case .dark: return .dark
    }
  }

  /// - returns: the color to use as a root background color for the app
  public var rootBackgroundColor: Color {
    switch self {
    case .system: return .clear
    case .light: return .white
    case .dark: return .black
    }
  }
}
