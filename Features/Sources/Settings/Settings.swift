// Copyright © 2025 Brad Howes. All rights reserved.

import FeatureSupport
import FileImporter
import Keyboard
import MIDIAssignments
import MIDIConnections
import MIDIControllers
import MIDITrafficIndicator
import MorkAndMIDI
import Tuning

@Reducer
public struct Settings {

  @Reducer
  public enum Path {
    case midiAssignments(MIDIAssignments)
    case midiConnections(MIDIConnections)
    case midiControllers(MIDIControllers)
  }

  @Reducer
  @frozen
  public enum Destination {
    case alert(AlertState<Alert>)
    case backupPicker(FilePicker)

    @CasePathable
    @frozen
    public enum Alert {
      case disableCopyFileConfirmed
      case disableIdleTimerConfirmed
      case restoreConfirmed
    }
  }

  @ObservableState
  public struct State: Equatable {
    public var path = StackState<Path.State>()
    @Presents public var destination: Destination.State?
    public var midiDevicesCount: Int = 0
    public var midiConnectedCount: Int = 0
    public var midiTrafficIndicator: MIDITrafficIndicator.State
    public var tuning: Tuning.State
    public let hasMIDI: Bool

    @Shared(.backgroundProcessing) public var backgroundProcessing
    @Shared(.colorSchemeBehavior) public var colorSchemeBehavior
    @Shared(.copyFileWhenInstalling) public var copyFileWhenInstalling
    @Shared(.disableIdleTimer) public var disableIdleTimer
    @Shared(.duckOtherApps) public var duckOtherApps
    @Shared(.favoritesOnTop) public var favoritesOnTop
    @Shared(.favoriteSymbolName) public var favoriteSymbolName
    @Shared(.hideBuiltinFonts) public var hideBuiltinFonts
    @Shared(.hideEmptyTags) public var hideEmptyTags
    @Shared(.keyboardSlides) public var keyboardSlides
    @Shared(.keyLabels) public var keyLabels
    @Shared(.keyWidth) public var keyWidth
    @Shared(.midiAutoConnect) public var midiAutoConnect
    @Shared(.midiChannel) public var midiChannel
    @Shared(.mixWithOtherApps) public var mixWithOtherApps
    @Shared(.pitchBendRange) public var pitchBendRange
    @Shared(.playSoundOnPresetChange) public var playSoundOnPresetChange
    @Shared(.showActiveVoiceCount) public var showActiveVoiceCount
    @Shared(.showKeyNotes) public var showKeyNotes
    @Shared(.showMIDINotesOnKeyboard) public var showMIDINotesOnKeyboard
    @Shared(.showMIDITrafficIndicator) public var showMIDITrafficIndicator
    @Shared(.showOnlyFavorites) public var showOnlyFavorites
    @Shared(.showSolfegeTags) public var showSolfegeTags
    @Shared(.sortPresetsByName) public var sortPresetsByName
    @Shared(.starFavoriteNames) public var starFavoriteNames

    public init(
      path: StackState<Path.State> = .init(),
      destination: Destination.State? = nil,
      midiDevicesCount: Int = 0,
      midiConnectedCount: Int = 0,
      midiTrafficIndicator: MIDITrafficIndicator.State = .init(tag: "Settings"),
      tuning: Tuning.State = Self.makeTuningState()
    ) {
      @Shared(.midi) var midi
      hasMIDI = midi != nil
      self.path = path
      self.destination = destination
      self.midiDevicesCount = midi?.sourceConnections.count ?? midiDevicesCount
      self.midiConnectedCount = midi?.sourceConnections.filter { $0.connected }.count ?? midiConnectedCount
      self.midiTrafficIndicator = midiTrafficIndicator
      self.tuning = tuning
    }

    public static func makeTuningState() -> Tuning.State {
      @Shared(.globalTuningEnabled) var globalTuningEnabled
      @Shared(.globalTuningFrequency) var globalTuningFrequency
      return .init(frequency: globalTuningFrequency, enabled: globalTuningEnabled)
    }
  }

  public enum Action: BindableAction {
    case binding(BindingAction<State>)
    case bluetoothMIDILocateButtonTapped
    case contactDeveloperTapped
    case createBackupTapped
    case delegate(Delegate)
    case destination(PresentationAction<Destination.Action>)
    case dismissButtonTapped
    case initialize
    case midiAssignmentsButtonTapped
    case midiConnectionsButtonTapped
    case midiConnectionsChanged
    case midiControllersButtonTapped
    case midiTrafficIndicator(MIDITrafficIndicator.Action)
    case path(StackActionOf<Path>)
    case restoreBackupTapped
    case restoreFailed(Error)
    case restoreFinished
    case reviewAppTapped
    case tuning(Tuning.Action)

    @CasePathable
    public enum Delegate {
      case reinitialize
      case showChanges
      case showTutorial
    }
  }

  public init() {}

  @Shared(.midi) var midi
  @Shared(.midiMonitor) var midiMonitor

  public var body: some ReducerOf<Self> {
    BindingReducer()

    Scope(state: \.midiTrafficIndicator, action: \.midiTrafficIndicator) { MIDITrafficIndicator() }
    Scope(state: \.tuning, action: \.tuning) { Tuning() }

    Reduce { state, action in

      log.action("Settiings", action)

      switch action {

      case .binding(\.keyWidth):
        return updateKeyWidth(&state)

      case .binding(\.copyFileWhenInstalling):
        if !state.copyFileWhenInstalling {
          state.$copyFileWhenInstalling.withLock { $0 = true }
          state.destination = .alert(.confirmDisableCopyFile(action: .disableCopyFileConfirmed))
        }
        return .none

      case .binding(\.disableIdleTimer):
        if state.disableIdleTimer {
          state.$disableIdleTimer.withLock { $0 = false }
          state.destination = .alert(.confirmDisableIdleTimer(action: .disableIdleTimerConfirmed))
        }
        return .none

      case .createBackupTapped:
        return backupToCloud(&state)

      case .destination(.presented(.alert(.disableCopyFileConfirmed))):
        state.$copyFileWhenInstalling.withLock { $0 = false }
        return .none

      case .destination(.presented(.alert(.disableIdleTimerConfirmed))):
        state.$disableIdleTimer.withLock { $0 = true }
        return .none

      case .destination(.presented(.backupPicker(.picked(let result)))):
        return restoreBackupPicked(&state, result: result)

      case .dismissButtonTapped:
        return dismissButtonTapped(&state)

      case .initialize:
        return initialize(&state)

      case .midiAssignmentsButtonTapped:
        state.path.append(.midiAssignments(MIDIAssignments.State()))
        return .none

      case .midiConnectionsButtonTapped:
        state.path.append(.midiConnections(MIDIConnections.State()))
        return .none

      case .midiConnectionsChanged:
        if let midi {
          state.midiDevicesCount = midi.sourceConnections.count
          state.midiConnectedCount = midi.sourceConnections.filter { $0.connected }.count
        }
        return .none

      case .midiControllersButtonTapped:
        state.path.append(.midiControllers(MIDIControllers.State()))
        return .none

      case .path(.popFrom(let id)):
        if case .midiConnections = state.path[id: id],
           let midi {
          state.midiDevicesCount = midi.sourceConnections.count
          state.midiConnectedCount = midi.sourceConnections.filter { $0.connected }.count
        }
        return .none

      case .restoreBackupTapped:
        return restoreBackupTapped(&state)

      case .restoreFailed(let error):
        state.destination = .alert(.restoreFailed(error))
        return .none

      case .restoreFinished:
        state.destination = .alert(.restoreFinished())
        return .none

      case let .tuning(.delegate(.tuningChanged(enabled, frequency))):
        return tuningChanged(&state, enabled: enabled, frequency: frequency)

      default:
        return .none
      }
    }
    .forEach(\.path, action: \.path)
    .ifLet(\.destination, action: \.destination)
  }

  private enum CancelId: String {
    case settingsMonitorMIDIConnections
  }
}

extension Settings {

  private func backupToCloud(_ state: inout State) -> Effect<Action> {

    do {
      let url = try BackupManager.backup()
      state.destination = .alert(.notifyBackupName(url.lastPathComponent))
    } catch {
      state.destination = .alert(.notifyBackupFailure(error.description))
    }
    return .none
  }

  private func dismissButtonTapped(_ state: inout State) -> Effect<Action> {
    @Dependency(\.dismiss) var dismiss
    return .run { _ in await dismiss() }
  }

  private func initialize(_ state: inout State) -> Effect<Action> {
    .merge(
      reduce(into: &state, action: .midiTrafficIndicator(.initialize)),
      monitorMIDIConnections(&state)
    )
  }

  private func monitorMIDIConnections(_ state: inout State) -> Effect<Action> {
    guard let midiMonitor else { return .none }
    return .run { send in
      for await _ in midiMonitor.$connectivity.values {
        await send(.midiConnectionsChanged)
      }
    }.cancellable(id: CancelId.settingsMonitorMIDIConnections)
  }

  private func restoreBackupPicked(_ state: inout State, result: Result<[URL], Error>) -> Effect<Action> {
    switch result {

    case .success(let urls):
      guard let url = urls.first else {
        log.error("Expected to have one URL from picker")
        return .none
      }

      return .run { send in
        do {
          try await BackupManager.restore(backupDirectory: url)
          await send(.restoreFinished)
        } catch {
          await send(.restoreFailed(error))
        }
      }

    case .failure(let error):
      log.error("Failed to pick backup - \(error.localizedDescription, privacy: .public)")
      return .none
    }
  }

  private func restoreBackupTapped(_ state: inout State) -> Effect<Action> {
    state.destination = .backupPicker(
      .init(
        types: [.folder, .directory],
        allowsMultipleSelection: false
      )
    )
    return .none
  }

  private func tuningChanged(_ state: inout State, enabled: Bool, frequency: Double) -> Effect<Action> {
    @Shared(.globalTuningEnabled) var globalTuningEnabled
    @Shared(.globalTuningFrequency) var globalTuningFrequency
    $globalTuningEnabled.withLock { $0 = enabled }
    $globalTuningFrequency.withLock { $0 = frequency }
    return .none
  }

  private func updateKeyWidth(_ state: inout State) -> Effect<Action> {
    var value = state.keyWidth
    for stop in [48.0, 64.0, 80.0] where Swift.abs(value - stop) < 3.0 {
      value = stop
      break
    }

    return updateShared(.keyWidth, value: value)
  }

  private func updateShared<T>(_ key: AppStorageKey<T>.Default, value: T) -> Effect<Action> {
    @Shared(key) var store
    $store.withLock { $0 = value }
    return .none
  }
}

extension Settings.Path.State: Equatable {}
extension Settings.Destination.State: Equatable {}
extension Settings.Destination.State: _EphemeralState {
  public typealias Action = Alert
}

private let log: Logger = .init(category: "AppSettings")
