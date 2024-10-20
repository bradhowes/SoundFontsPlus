import ComposableArchitecture
import Models
import SwiftUI

public enum Support {

  static func generateTagsList(from soundFont: SoundFontModel) -> String {
    soundFont.tags.map(\.name).sorted().joined(separator: ", ")
  }
}

extension View {
  func swipeToDeleteSoundFont(
    enabled: Bool,
    showingConfirmation: Binding<Bool>,
    key: SoundFontModel.Key,
    name: String,
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
      "Are you sure you want to delete \(name)? You will lose all customizations for this sound font.",
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
