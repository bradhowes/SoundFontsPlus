// Copyright © 2025 Brad Howes. All rights reserved.

import FeatureSupport
import UniformTypeIdentifiers
import SwiftUI

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
    public var showPicker: Bool
    @Presents public var destination: Destination.State?

    public var restorePending: URL?

    public init(showPicker: Bool = false, destination: Destination.State? = nil) {
      self.showPicker = showPicker
      self.destination = destination
    }
  }

  public enum Action {
    case delegate(Delegate)
    case destination(PresentationAction<Destination.Action>)
    case pickerDismissed
    case picked(Result<[URL], Error>)
    case showPicker

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
        state.showPicker = false
        return .none

      case .pickerDismissed:
        state.showPicker = false
        return .none

      case .picked(let result):
        return backupPicked(&state, result: result)

      case .showPicker:
        state.showPicker = true
        return .none

      default:
        return .none
      }
    }
    .ifLet(\.destination, action: \.destination)
  }
}

extension BackupPicker {

  private func backupPicked(_ state: inout State, result: Result<[URL], Error>) -> Effect<Action> {
    log.debug("backupPicked - \(String(describing: result), privacy: .public)")

    state.showPicker = false

    switch result {

    case .success(let urls):
      state.restorePending = urls[0]
      state.destination = .alert(.confirmBackupRestore(action: .restoreConfirmed, displayName: urls[0].lastPathComponent))
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

public struct BackupPickerViewModifier: ViewModifier {
  @Bindable private var store: StoreOf<BackupPicker>

  public init(store: StoreOf<BackupPicker>) {
    self.store = store
  }

  public func body(content: Content) -> some View {
    content
      .fileImporter(
        isPresented: Binding(
          get: { store.showPicker },
          set: { _ in store.send(.pickerDismissed) }
        ),
        allowedContentTypes: store.types,
        allowsMultipleSelection: false
      ) { result in
        store.send(.picked(result))
      }
      .alert($store.scope(state: \.destination?.alert, action: \.destination.alert))
  }
}

extension View {

  public func backupPickerFeature(_ store: StoreOf<BackupPicker>) -> some View {
    modifier(BackupPickerViewModifier(store: store))
  }
}

private let log: Logger = .init(category: "BackupImporter")
