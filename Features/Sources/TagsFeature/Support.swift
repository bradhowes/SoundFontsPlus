import ComposableArchitecture
import GRDB
import Models
import SF2ResourceFiles
import SwiftUI

enum Support {

  @CasePathable
  public enum ConfirmationDialog: Equatable, Sendable {
    case confirmedDeletion(key: Tag.ID)
  }
}
