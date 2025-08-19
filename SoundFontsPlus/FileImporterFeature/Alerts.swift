import ComposableArchitecture
import SwiftUI

extension AlertState {

  static func addedSummary(displayName: String) -> Self {
    Self {
      TextState("Added")
    } actions: {
      ButtonState(role: .cancel) {
        TextState("OK")
      }
    } message: {
      TextState("Successfully addeed sound font '\(displayName)'.")
    }
  }

  static func continueWithDuplicateFile(url: URL, action: Action) -> Self {
    Self {
      TextState("Duplicate File")
    } actions: {
      ButtonState(action: action) {
        TextState("Continue")
      }
      ButtonState(role: .cancel) {
        TextState("Cancel")
      }
    } message: {
      let baseName = url.lastPathComponent
      return TextState(
      """
      The file "\(baseName)" already exists. \
      You can continue to add it, but you may see duplicate entries.
      """
      )
    }
  }

  static func failedToPick(error: Error) -> Self {
    Self {
      TextState("Failed to Pick")
    } actions: {
      ButtonState(role: .cancel) {
        TextState("OK")
      }
    } message: {
      TextState("\(error.localizedDescription)")
    }
  }

  static func genericFailureToImport(displayName: String, error: Error) -> Self {
    Self {
      TextState("Failed to Add")
    } actions: {
      ButtonState(role: .cancel) {
        TextState("OK")
      }
    } message: {
      TextState("\(error.localizedDescription)")
    }
  }

  static func invalidSoundFontFormat(displayName: String) -> Self {
    Self {
      TextState("Invalid SF2 File")
    } actions: {
      ButtonState(role: .cancel) {
        TextState("OK")
      }
    } message: {
      TextState("'\(displayName)' does not appear to be a valid sound font file.")
    }
  }
}

@Reducer
private struct AlertDemo {

  @Reducer(state: .equatable)
  fileprivate enum Destination: Equatable {
    case alert(AlertState<Alert>)

    @CasePathable
    fileprivate enum Alert {
      case addedSummary
      case continueWithDuplicateFile
      case failedToPick
      case genericFailureToImport
      case invalidSoundFontFormat
    }
  }

  @ObservableState
  fileprivate struct State: Equatable {
    @Presents var destination: Destination.State?
  }

  fileprivate enum Action {
    case addedSummary
    case continueWithDuplicateFile
    case destination(PresentationAction<Destination.Action>)
    case failedToPick
    case genericFailureToImport
    case invalidSoundFontFormat
  }

  @Dependency(\.dismiss) var dismiss

  fileprivate var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .addedSummary:
        state.destination = .alert(.addedSummary(displayName: "Foo"))
        return .none

      case .continueWithDuplicateFile:
        state.destination = .alert(AlertState<Destination.Alert>.continueWithDuplicateFile(
          // swiftlint:disable:next force_unwrapping
          url: URL(filePath: "file://one/two/three.sf2")!,
          action: Destination.Alert.continueWithDuplicateFile
        ))
        return .none

      case .destination(.presented(.alert)):
        return .none

      case .destination:
        return .none

      case .failedToPick:
        state.destination = .alert(.failedToPick(error: ModelError.invalidLocation(name: "blah")))
        return .none

      case .genericFailureToImport:
        state.destination = .alert(.genericFailureToImport(
          displayName: "Foo Bar",
          error: ModelError.failedToSave(name: "Blahblahblah")
        ))
        return .none

      case .invalidSoundFontFormat:
        state.destination = .alert(.invalidSoundFontFormat(displayName: "Invalid Sound Font"))
        return .none
      }
    }
  }
}

private struct AlertDemoView: View {
  @State private var store: StoreOf<AlertDemo>

  fileprivate init(store: StoreOf<AlertDemo>) {
    self.store = store
  }

  var body: some View {
    VStack {
      Button {
        store.send(.addedSummary)
      } label: {
        Text("Added Summary")
      }
      Button {
        store.send(.continueWithDuplicateFile)
      } label: {
        Text("Continue with Dup File")
      }
      Button {
        store.send(.failedToPick)
      } label: {
        Text("Failed to Pick")
      }
      Button {
        store.send(.genericFailureToImport)
      } label: {
        Text("Generic Failure")
      }
      Button {
        store.send(.invalidSoundFontFormat)
      } label: {
        Text("Invalid Format")
      }
    }
    .alert($store.scope(state: \.destination?.alert, action: \.destination.alert))
  }
}

#Preview {
  AlertDemoView(store: Store(initialState: .init()) { AlertDemo() })
}
