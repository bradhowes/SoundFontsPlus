// Copyright © 2025 Brad Howes. All rights reserved.

import Sharing
import SwiftUI

struct DarkModeViewModifier: ViewModifier {
  @Shared(.colorSchemeBehavior) var colorSchemeBehavior

  public func body(content: Content) -> some View {
    content
      .preferredColorScheme(colorSchemeBehavior.preferredColorScheme)
  }
}

extension View {

  public func darkMode() -> some View {
    self.modifier(DarkModeViewModifier())
  }
}
