import ComposableArchitecture
import Models
import SwiftUI

public enum Support {

  @CasePathable
  public enum ConfirmationDialog: Equatable, Sendable {
    case confirmedDeletion(key: Tag.ID)
  }
}

extension ConfirmationDialogState where Action == Support.ConfirmationDialog {

  public static func tagDeletion(_ key: Tag.ID, name: String) -> Self {
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

//extension View {
//
//  func swipeToDelete(
//    enabled: Bool,
//    showingConfirmation: Binding<Bool>,
//    name: String,
//    confirmationAction: @escaping () -> Void
//  ) -> some View {
//    self.swipeActions {
//      if enabled {
//        Button {
//          showingConfirmation.wrappedValue = true
//        } label: {
//          Label("Delete", systemImage: "trash")
//            .tint(.red)
//        }
//      }
//    }.confirmationDialog(
//      "Are you sure you want to delete tag \(name)?",
//      isPresented: showingConfirmation,
//      titleVisibility: .visible
//    ) {
//      Button("Confirm", role: .destructive) {
//        confirmationAction()
//      }
//      Button("Cancel", role: .cancel) {
//        showingConfirmation.wrappedValue = false
//      }
//    }
//  }
//}
