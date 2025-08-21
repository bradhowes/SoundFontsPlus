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
      Direct file access may lead to unusable SF2 file references if the file moves or is not immediately available on the
      device. Are you sure you want to disable copying?
      """
      )
    }
  }
}
