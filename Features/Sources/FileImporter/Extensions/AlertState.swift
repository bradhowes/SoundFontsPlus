// Copyright © 2025 Brad Howes. All rights reserved.

import ComposableArchitecture
import Models
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

  static func fileAlreadyImported(url: URL) -> Self {
    Self {
      TextState("Already Imported")
    } actions: {
      ButtonState(role: .cancel) {
        TextState("OK")
      }
    } message: {
      let baseName = url.lastPathComponent
      return TextState(
      """
      The file "\(baseName)" already exists in the collection.
      """
      )
    }
  }

  static func failedToCopy(displayName: String) -> Self {
    Self {
      TextState("Failed to Copy")
    } actions: {
      ButtonState(role: .cancel) {
        TextState("OK")
      }
    } message: {
      return TextState(
      """
      Failed to copy "\(displayName)" to application folder.
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

  @Reducer
  fileprivate enum Destination: Equatable {
    case alert(AlertState<Alert>)

    @CasePathable
    fileprivate enum Alert {
      case addedSummary
      case failedToPick
      case fileAlreadyImported
      case genericFailureToImport
      case invalidSoundFontFormat
    }
  }

  @ObservableState
  fileprivate struct State: Equatable {
    @Presents var destination: Destination.State?
    var fileImporter: FileImporter.State = .init()
  }

  fileprivate enum Action {
    case addedSummary
    case beginTapped
    case destination(PresentationAction<Destination.Action>)
    case failedToPick
    case fileAlreadyImported
    case fileImporter(FileImporter.Action)
    case genericFailureToImport
    case invalidSoundFontFormat
  }

  @Dependency(\.dismiss) var dismiss

  fileprivate var body: some ReducerOf<Self> {

    Scope(state: \.fileImporter, action: \.fileImporter) { FileImporter() }

    Reduce { state, action in
      switch action {
      case .addedSummary:
        state.destination = .alert(.addedSummary(displayName: "Foo"))
        return .none

      case .beginTapped:
        state.fileImporter.showChooser = true
        return .none

      case .destination(.presented(.alert)):
        return .none

      case .destination:
        return .none

      case .failedToPick:
        state.destination = .alert(.failedToPick(error: ModelError.loadFailure(url: URL(filePath: "blah")!)))
        return .none

      case .fileAlreadyImported:
        state.destination = .alert(.fileAlreadyImported(
          // swiftlint:disable:next force_unwrapping
          url: URL(filePath: "file://one/two/three.sf2")!
        ))
        return .none

      case .fileImporter:
        return .none

      case .genericFailureToImport:
        state.destination = .alert(.genericFailureToImport(
          displayName: "Foo Bar",
          error: ModelError.loadFailure(url: URL(filePath: "blah")!)
        ))
        return .none

      case .invalidSoundFontFormat:
        state.destination = .alert(.invalidSoundFontFormat(displayName: "Invalid Sound Font"))
        return .none
      }
    }
  }
}

extension AlertDemo.Destination.State: Equatable {}

private struct AlertDemoView: View {
  @State private var store: StoreOf<AlertDemo>

  fileprivate init(store: StoreOf<AlertDemo>) {
    self.store = store
  }

  var body: some View {
    VStack {
      Button {
        store.send(.beginTapped)
      } label: {
        Text("Begin File Importer")
      }
      Button {
        store.send(.addedSummary)
      } label: {
        Text("Added Summary")
      }
      Button {
        store.send(.fileAlreadyImported)
      } label: {
        Text("Already Imported")
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
    .fileImporterFeature(store.scope(state: \.fileImporter, action: \.fileImporter))
    .alert($store.scope(state: \.destination?.alert, action: \.destination.alert))
  }
}

#Preview {
  AlertDemoView(store: Store(initialState: .init()) { AlertDemo() })
}
