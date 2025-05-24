import ComposableArchitecture

enum TagSupport {

  @CasePathable
  public enum ConfirmationDialog: Equatable, Sendable {
    case confirmedDeletion(key: Tag.ID)
  }
}
