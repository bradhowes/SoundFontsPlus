// Copyright © 2025 Brad Howes. All rights reserved.

import SwiftUI

extension EnvironmentValues {
  @Entry public var appPanelBackground: Color = .init(red: 0.08, green: 0.08, blue: 0.08)
  @Entry public var compactKeyboardPanelHeightScaling: Double = 0.5
  @Entry public var effectsPanelHeight: Double = 110.0
  @Entry public var maxKeyboardPanelHeight: Double = 200.0
}

extension View {
  public func appPanelBackground(_ value: Color) -> some View {
    environment(\.appPanelBackground, value)
  }

  public func compactKeyboardPanelHeightScaling(_ value: Double) -> some View {
    environment(\.compactKeyboardPanelHeightScaling, value)
  }

  public func effectsPanelHeight(_ value: Double) -> some View {
    environment(\.effectsPanelHeight, value)
  }

  public func maxKeyboardPanelHeight(_ value: Double) -> some View {
    environment(\.maxKeyboardPanelHeight, value)
  }
}
