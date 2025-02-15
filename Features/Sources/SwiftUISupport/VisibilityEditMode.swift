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
  public func visbilityEditModel(_ editMode: EditMode) -> some View {
    environment(\.visibilityEditMode, editMode)
  }
}
#endif
