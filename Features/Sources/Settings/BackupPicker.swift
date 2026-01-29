// Copyright © 2025 Brad Howes. All rights reserved.

import FeatureSupport
import UniformTypeIdentifiers

/**
 Feature that imports an SF2 file for use in the synth.
 */
@Reducer
public struct BackupPicker {

  @Reducer
  public enum Destination: Equatable {
    case alert(AlertState<Alert>)

    @CasePathable
    public enum Alert: Equatable {
      case restoreConfirmed
    }
  }

  @ObservableState
  public struct State: Equatable {
    public let types: [UTType] = [.folder, .directory]
    public var showChooser: Bool
    @Presents public var destination: Destination.State?

    public var restorePending: URL?

    public init(showChooser: Bool = false, destination: Destination.State? = nil) {
      self.showChooser = showChooser
      self.destination = destination
    }
  }

  public enum Action {
    case delegate(Delegate)
    case destination(PresentationAction<Destination.Action>)
    case backupImporterDismissed
    case backupPicked(Result<URL, Error>)
    case showBackupImporter

    public enum Delegate {
      case importConfirmed(URL)
    }
  }

  public init() {}

  @Dependency(\.fileManager) private var fileManager
  @Dependency(\.dismiss) private var dismiss

  public var body: some ReducerOf<Self> {
    Reduce { state, action in

      log.action("BackupImporter", action)

      switch action {

      case .destination(.presented(.alert(.restoreConfirmed))):
        guard let restorePending = state.restorePending else { return .none }
        return .send(.delegate(.importConfirmed(restorePending)))

      case .destination(.dismiss):
        state.showChooser = false
        return .none

      case .backupImporterDismissed:
        state.showChooser = false
        return .none

      case .backupPicked(let result):
        return backupPicked(&state, result: result)

      case .showBackupImporter:
        state.showChooser = true
        return .none

      default:
        return .none
      }
    }
    .ifLet(\.destination, action: \.destination)
  }
}

extension BackupPicker {

  private func backupPicked(_ state: inout State, result: Result<URL, Error>) -> Effect<Action> {
    log.debug("backupPicked - \(String(describing: result), privacy: .public)")

    state.showChooser = false

    switch result {

    case .success(let url):
      state.restorePending = url
      state.destination = .alert(.confirmBackupRestore(action: .restoreConfirmed, displayName: url.lastPathComponent))
      return .none

    case .failure:
      return .none
    }
  }

  private func validatePickedBackup(_ url: URL) -> Bool {
    return false
  }
}

extension BackupPicker.Destination.State: Equatable {}
extension BackupPicker.Destination.State: _EphemeralState {
  public typealias Action = Alert
}

private let log: Logger = .init(category: "BackupImporter")
