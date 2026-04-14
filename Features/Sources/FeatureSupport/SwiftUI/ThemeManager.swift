// Copyright © 2025 Brad Howes. All rights reserved.

import Sharing
import SwiftUI

struct ColorSchemeViewModifier: ViewModifier {
  @Shared(.colorSchemeBehavior) var colorSchemeBehavior

  public func body(content: Content) -> some View {
    content
      .preferredColorScheme(colorSchemeBehavior.preferredColorScheme)
  }
}

extension View {

  public func useColorScheme() -> some View {
    self.modifier(ColorSchemeViewModifier())
  }
}
