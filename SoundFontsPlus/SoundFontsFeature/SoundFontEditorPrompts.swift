import ComposableArchitecture

extension AlertState {

  static func confirmShowHiddenPresets(action: Action) -> Self {
    Self {
      TextState("Unhide Presets?")
    } actions: {
      ButtonState(action: action) {
        TextState("Yes")
      }
      ButtonState(role: .cancel) {
        TextState("Cancel")
      }
    } message: {
      TextState(
"""
Confirm to immediately unhide all of the hidden presets.
"""
      )
    }
  }
}
