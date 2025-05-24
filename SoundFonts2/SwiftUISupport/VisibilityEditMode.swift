// Copyright © 2025 Brad Howes. All rights reserved.

import SwiftUI

#if os(iOS)
private struct VisibilityEditMode: EnvironmentKey {
  static let defaultValue: EditMode = .inactive
}

extension EnvironmentValues {
  var visibilityEditMode: EditMode {
    get { self[VisibilityEditMode.self] }
    set { self[VisibilityEditMode.self] = newValue }
  }
}

extension View {
  public func visbilityEditMode(_ editMode: EditMode) -> some View {
    environment(\.visibilityEditMode, editMode)
  }
}
#endif
