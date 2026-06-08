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

  public enum SectionId: Equatable, Hashable, Identifiable, CaseIterable {
    public var id: Self { self }

    case presets
    case fonts
    case keys
    case midi
    case tuning
    case app
    case about

    public var label: String {
      switch self {
      case .presets: return "Presets"
      case .fonts: return "Fonts"
      case .keys: return "Keys"
      case .midi: return "MIDI"
      case .tuning: return "Tuning"
      case .app: return "App"
      case .about: return "About"
      }
    }
  }

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
    public var copyFileWhenInstalling: Bool
    public var disableIdleTimer: Bool
    public var keyWidth: Double
    public var currentSection: SectionId = .presets
    public var sectionJump: SectionId = .presets

    @ObservationStateIgnored
    @Shared(.backgroundProcessing) public var backgroundProcessing
    @ObservationStateIgnored
    @Shared(.colorSchemeBehavior) public var colorSchemeBehavior
    @ObservationStateIgnored
    @Shared(.duckOtherApps) public var duckOtherApps
    @ObservationStateIgnored
    @Shared(.favoritesOnTop) public var favoritesOnTop
    @ObservationStateIgnored
    @Shared(.favoriteSymbolName) public var favoriteSymbolName
    @ObservationStateIgnored
    @Shared(.hideBuiltinFonts) public var hideBuiltinFonts
    @ObservationStateIgnored
    @Shared(.hideEmptyTags) public var hideEmptyTags
    @ObservationStateIgnored
    @Shared(.keyboardSlides) public var keyboardSlides
    @ObservationStateIgnored
    @Shared(.keyLabels) public var keyLabels
    @ObservationStateIgnored
    @Shared(.midiAutoConnect) public var midiAutoConnect
    @ObservationStateIgnored
    @Shared(.midiChannel) public var midiChannel
    @ObservationStateIgnored
    @Shared(.mixWithOtherApps) public var mixWithOtherApps
    @ObservationStateIgnored
    @Shared(.pitchBendRange) public var pitchBendRange
    @ObservationStateIgnored
    @Shared(.playSoundOnPresetChange) public var playSoundOnPresetChange
    @ObservationStateIgnored
    @Shared(.showActiveVoiceCount) public var showActiveVoiceCount
    @ObservationStateIgnored
    @Shared(.showKeyNotes) public var showKeyNotes
    @ObservationStateIgnored
    @Shared(.showMIDINotesOnKeyboard) public var showMIDINotesOnKeyboard
    @ObservationStateIgnored
    @Shared(.showMIDITrafficIndicator) public var showMIDITrafficIndicator
    @ObservationStateIgnored
    @Shared(.showOnlyFavorites) public var showOnlyFavorites
    @ObservationStateIgnored
    @Shared(.showPresetIndexView) public var showPresetIndexView
    @ObservationStateIgnored
    @Shared(.showSolfegeTags) public var showSolfegeTags
    @ObservationStateIgnored
    @Shared(.sortPresetsByName) public var sortPresetsByName
    @ObservationStateIgnored
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
      @Shared(.keyWidth) var keyWidth
      self.keyWidth = keyWidth
      @Shared(.copyFileWhenInstalling) var copyFileWhenInstalling
      self.copyFileWhenInstalling = copyFileWhenInstalling
      @Shared(.disableIdleTimer) var disableIdleTimer
      self.disableIdleTimer = disableIdleTimer
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

  @Dependency(\.dismiss) var dismiss

  public var body: some ReducerOf<Self> {
    BindingReducer()

    Scope(state: \.midiTrafficIndicator, action: \.midiTrafficIndicator) { MIDITrafficIndicator() }
    Scope(state: \.tuning, action: \.tuning) { Tuning() }

    Reduce { state, action in

      log.action("Settiings", action)

      switch action {

      case .binding(\.copyFileWhenInstalling):
        if !state.copyFileWhenInstalling {
          // Undo change until confirmed.
          state.copyFileWhenInstalling = true
          state.destination = .alert(.confirmDisableCopyFile(action: .disableCopyFileConfirmed))
        }
        return .none

      case .binding(\.disableIdleTimer):
        if state.disableIdleTimer {
          // Undo change until confirmed.
          state.disableIdleTimer = false
          state.destination = .alert(.confirmDisableIdleTimer(action: .disableIdleTimerConfirmed))
        }
        return .none

      case .binding(\.keyWidth):
        return updateKeyWidth(&state)

      case .binding(\.currentSection):
        state.sectionJump = state.currentSection
        return .none

      case .destination(.presented(.alert(.disableCopyFileConfirmed))):
        @Shared(.copyFileWhenInstalling) var copyFileWhenInstalling
        $copyFileWhenInstalling.withLock { $0 = false }
        state.copyFileWhenInstalling = false
        return .none

      case .destination(.presented(.alert(.disableIdleTimerConfirmed))):
        @Shared(.disableIdleTimer) var disableIdleTimer
        $disableIdleTimer.withLock { $0 = true }
        state.disableIdleTimer = true
        return .none

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
        @Shared(.midi) var midi
        if let midi {
          state.midiDevicesCount = midi.sourceConnections.count
          state.midiConnectedCount = midi.sourceConnections.filter { $0.connected }.count
        }
        return .none

      case .midiControllersButtonTapped:
        state.path.append(.midiControllers(MIDIControllers.State()))
        return .none

      case .path(.popFrom(let id)):
        @Shared(.midi) var midi
        if case .midiConnections = state.path[id: id],
           let midi {
          state.midiDevicesCount = midi.sourceConnections.count
          state.midiConnectedCount = midi.sourceConnections.filter { $0.connected }.count
        }
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
    return .run { [dismiss] _ in await dismiss() }
  }

  private func initialize(_ state: inout State) -> Effect<Action> {
    .merge(
      .send(.midiTrafficIndicator(.initialize)),
      monitorMIDIConnections(&state)
    )
  }

  private func monitorMIDIConnections(_ state: inout State) -> Effect<Action> {
    @Shared(.midiMonitor) var midiMonitor
    guard let midiMonitor else { return .none }
    return .run { send in
      for await _ in midiMonitor.$connectivity.values {
        await send(.midiConnectionsChanged)
      }
    }.cancellable(id: CancelId.settingsMonitorMIDIConnections)
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
