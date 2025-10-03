import ComposableArchitecture

extension AlertState {

  static func confirmHidePreset(action: Action, displayName: String) -> Self {
    Self {
      TextState("Hide '\(displayName)'?")
    } actions: {
      ButtonState(action: action) { TextState("Hide") }
      ButtonState(role: .cancel) { TextState("Cancel") }
    } message: {
      TextState(
"""
Hiding a preset will keep it from appearing in the list of presets. \
You can restore visibility via the preset visibility button in the toolbar.
"""
      )
    }
  }

  static func confirmDeleteFavorite(action: Action, displayName: String) -> Self {
    Self {
      TextState("Delete '\(displayName)'?")
    } actions: {
      ButtonState(role: .destructive, action: action) { TextState("Delete") }
      ButtonState(role: .cancel) { TextState("Cancel") }
    } message: {
      TextState(
"""
Deleting a favorite cannot be undone.
"""
      )
    }
  }
}

extension AlertState {

  static func confirmDisableCopyFile(action: Action) -> Self {
    Self {
      TextState("Disable Copying?")
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
      Not copying SF2 files may lead to unusable fonts if the file moves or is not immediately available on the
      device.
      """
      )
    }
  }

  static func confirmDisableIdleTimer(action: Action) -> Self {
    Self {
      TextState("Disable Device Locking?")
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
      Disabling will prevent the device from sleeping and locking the screen, resulting in increased battery usage
      and reduced security when unattended.
      """
      )
    }
  }
}

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
