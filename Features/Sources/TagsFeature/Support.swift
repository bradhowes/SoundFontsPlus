import ComposableArchitecture
import Models

public enum Support {

  @CasePathable
  public enum Alert: Equatable, Sendable {
    case confirmedDeletion(key: TagModel.Key)
  }

  @CasePathable
  public enum ConfirmationDialog: Equatable, Sendable {
    case confirmedDeletion(key: TagModel.Key)
  }
}

extension AlertState where Action == Support.Alert {

  public static func confirmTagDeletion(_ key: TagModel.Key, name: String) -> Self {
    .init {
      TextState("Delete?")
    } actions: {
      ButtonState(role: .destructive, action: .confirmedDeletion(key: key)) {
        TextState("Yes")
      }
      ButtonState(role: .cancel) {
        TextState("No")
      }
    } message: {
      TextState("Are you sure you want to delete tag \"\(name)\"?")
    }
  }
}

extension ConfirmationDialogState where Action == Support.ConfirmationDialog {

  public static func tagDeletion(_ key: TagModel.Key, name: String) -> Self {
    .init(titleVisibility: .visible) {
      TextState("Delete?")
    } actions: {
      ButtonState(role: .destructive, action: .confirmedDeletion(key: key)) {
        TextState("Yes")
      }
      ButtonState(role: .cancel) {
        TextState("No")
      }
    } message: {
      TextState("Are you sure you want to delete tag \"\(name)\"?")
    }
  }
}
