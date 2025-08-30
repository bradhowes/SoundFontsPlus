import ComposableArchitecture

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
