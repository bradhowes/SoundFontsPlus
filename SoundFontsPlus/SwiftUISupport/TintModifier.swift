// Copyright © 2025 Brad Howes. All rights reserved.

import SwiftUI

extension View {

  public func tint(if value: Bool) -> some View {
    self.tint(value ? Color.orange : Color.accentColor)
  }
}
