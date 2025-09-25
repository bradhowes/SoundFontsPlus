// Copyright © 2025 Brad Howes. All rights reserved.

import SwiftUI

extension EnvironmentValues {
  @Entry public var appPanelBackground: Color = .init(red: 0.08, green: 0.08, blue: 0.08)
  @Entry public var keyboardHeight: Double = 200.0
  @Entry public var effectsHeight: Double = 102.0
}

extension View {
  public func appPanelBackground(_ value: Color) -> some View { environment(\.appPanelBackground, value) }
  public func keyboardHeight(_ value: Double) -> some View { environment(\.keyboardHeight, value) }
}
