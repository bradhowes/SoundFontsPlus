import SwiftUI

extension View {

  public func swipeActionWithConfirmation(
    _ query: String,
    enabled: Bool,
    showingConfirmation: Binding<Bool>,
    confirmationAction: @escaping () -> Void
  ) -> some View {
    self.swipeActions {
      if enabled {
        Button {
          showingConfirmation.wrappedValue = true
        } label: {
          Label("Delete", systemImage: "trash")
            .tint(.red)
        }
      }
    }.confirmationDialog(
      query,
      isPresented: showingConfirmation,
      titleVisibility: .visible
    ) {
      Button("Confirm", role: .destructive) {
        confirmationAction()
      }
      Button("Cancel", role: .cancel) {
        showingConfirmation.wrappedValue = false
      }
    }
  }
}
