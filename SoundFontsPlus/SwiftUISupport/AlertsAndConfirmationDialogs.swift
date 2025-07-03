// Copyright © 2025 Brad Howes. All rights reserved.

import ComposableArchitecture
import Foundation
import UniformTypeIdentifiers.UTType
import SwiftUI

@Reducer
struct AlertAndConfirmationDialog {
  @ObservableState
  struct State: Equatable {
    @Presents var alert: AlertState<Action.Alert>?
    @Presents var confirmationDialog: ConfirmationDialogState<Action.ConfirmationDialog>?
    var count = 0
  }

  enum Action {
    case alert(PresentationAction<Alert>)
    case alertButtonTapped
    case confirmationDialog(PresentationAction<ConfirmationDialog>)
    case confirmationDialogButtonTapped

    @CasePathable
    enum Alert {
      case incrementButtonTapped
    }
    @CasePathable
    enum ConfirmationDialog {
      case incrementButtonTapped
      case decrementButtonTapped
    }
  }

  var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {
      case .alert(.presented(.incrementButtonTapped)),
          .confirmationDialog(.presented(.incrementButtonTapped)):
        state.alert = AlertState { TextState("Incremented!") }
        state.count += 1
        return .none

      case .alert:
        return .none

      case .alertButtonTapped:
        state.alert = AlertState {
          TextState("Alert!")
        } actions: {
          ButtonState(role: .cancel) {
            TextState("Cancel")
          }
          ButtonState(action: .incrementButtonTapped) {
            TextState("Increment")
          }
        } message: {
          TextState("This is an alert")
        }
        return .none

      case .confirmationDialog(.presented(.decrementButtonTapped)):
        state.alert = AlertState { TextState("Decremented!") }
        state.count -= 1
        return .none

      case .confirmationDialog:
        return .none

      case .confirmationDialogButtonTapped:
        state.confirmationDialog = ConfirmationDialogState {
          TextState("Confirmation dialog")
        } actions: {
          ButtonState(role: .cancel) {
            TextState("Cancel")
          }
          ButtonState(action: .incrementButtonTapped) {
            TextState("Increment")
          }
          ButtonState(action: .decrementButtonTapped) {
            TextState("Decrement")
          }
        } message: {
          TextState("This is a confirmation dialog.")
        }
        return .none
      }
    }
    .ifLet(\.$alert, action: \.alert)
    .ifLet(\.$confirmationDialog, action: \.confirmationDialog)
  }
}

struct AlertAndConfirmationDialogView: View {
  @Bindable var store: StoreOf<AlertAndConfirmationDialog>

  var body: some View {
    Form {
      Text("Count: \(store.count)")
      Button("Alert") { store.send(.alertButtonTapped) }
    }
    .navigationTitle("Alerts & Dialogs")
    .toolbar {
      Button("Confirmation Dialog") { store.send(.confirmationDialogButtonTapped) }
        .confirmationDialog($store.scope(state: \.confirmationDialog, action: \.confirmationDialog))
    }
    .alert($store.scope(state: \.alert, action: \.alert))
  }
}

#Preview {
  NavigationStack {
    AlertAndConfirmationDialogView(
      store: Store(initialState: AlertAndConfirmationDialog.State()) {
        AlertAndConfirmationDialog()
      }
    )
  }
}


struct FileDetails: Identifiable {
  var id: String { name }
  let name: String
  let fileType: UTType
}

struct ConfirmFileImport: View {
  @State private var isConfirming = false
  @State private var dialogDetail: FileDetails?
  var body: some View {
    Button("Import File") {
      dialogDetail = FileDetails(
        name: "MyImageFile.png", fileType: .png)
      isConfirming = true
    }
    .confirmationDialog(
      "Are you sure you want to import this file?",
      isPresented: $isConfirming, presenting: dialogDetail
    ) { detail in
      Button {
        // Handle import action.
      } label: {
        Text("""
                Import \(detail.name)
                File Type: \(detail.fileType.description)
                """)
      }
      Button {
        // Handle import action.
      } label: {
        Text("Another Button")
      }
      Button("Cancel", role: .cancel) {
        dialogDetail = nil
      }
    }
  }
}

