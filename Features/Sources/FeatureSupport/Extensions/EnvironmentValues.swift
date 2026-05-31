// Copyright © 2025 Brad Howes. All rights reserved.

import SwiftUI

extension EnvironmentValues {
  @Entry public var compactKeyboardPanelHeightScaling: Double = 0.5
  @Entry public var maxKeyboardPanelHeight: Double = 200.0
  @Entry public var controlSpacing: Double = 8.0
}

extension View {

  public func compactKeyboardPanelHeightScaling(_ value: Double) -> some View {
    environment(\.compactKeyboardPanelHeightScaling, value)
  }

  public func maxKeyboardPanelHeight(_ value: Double) -> some View {
    environment(\.maxKeyboardPanelHeight, value)
  }

  public func controlSpacing(_ value: Double) -> some View {
    environment(\.controlSpacing, value)
  }
}
