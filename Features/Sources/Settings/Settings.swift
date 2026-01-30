// Copyright © 2025 Brad Howes. All rights reserved.

import FeatureSupport
import FileImporter
import Keyboard
import MIDIAssignments
import MIDIConnections
import MIDIControllers
import MIDITrafficIndicator
import MorkAndMIDI
import SwiftToasts
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
    public var showProgressIndicator: Bool = false

    @Shared(.backgroundProcessing) public var backgroundProcessing
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
    case restoreFreshInstallTapped
    case reviewAppTapped
    case tuning(Tuning.Action)

    @CasePathable
    public enum Delegate {
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
        state.showProgressIndicator = false
        state.destination = .alert(.restoreFailed(error))
        return .none

      case .restoreFinished:
        state.showProgressIndicator = false
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

      state.showProgressIndicator = true

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
    state.destination = .backupPicker(.init(types: [.folder, .directory], allowsMultipleSelection: false))
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

public struct SettingsView: View {
  @Bindable private var store: StoreOf<Settings>
  @State private var changingKeyWidth: Bool = false
  @Shared(.isAUv3) private var isAUv3
  @Dependency(\.audioSession) private var audioSession
  @Dependency(\.fileManager) private var fileManager

  private let showFakeKeyboard: Bool
  private let bundle = Bundle.main

  public init(store: StoreOf<Settings>, showFakeKeyboard: Bool) {
    self.store = store
    self.showFakeKeyboard = showFakeKeyboard
  }

  public var body: some View {
    NavigationStack(path: $store.scope(state: \.path, action: \.path)) {
      Form {
        presetsSection
        if !isAUv3 {
          keyboardSection
          if store.hasMIDI {
            midiSection
          }
        }
        tuningSection
        fontsSection
        appSection
        aboutSection
      }
      .font(.settings)
      .formStyle(.grouped)
      .circledCheckMarkToggleStyle()
      .navigationTitle("Settings")
      .toolbar {
        ToolbarItem(placement: .automatic) {
          Button("Done") { store.send(.dismissButtonTapped, animation: .default) }
            .font(.button)
        }
      }
      .animation(.smooth, value: changingKeyWidth)
    } destination: { store in
      switch store.case {
      case .midiAssignments(let store): MIDIAssignmentsView(store: store)
      case .midiConnections(let store): MIDIConnectionsView(store: store)
      case .midiControllers(let store): MIDIControllersView(store: store)
      }
    }
    .toast(isPresented: $store.showProgressIndicator, alignment: .center) {
      restoringProgressToast
    }
    .toastStyle(.plain)
    .alert($store.scope(state: \.destination?.alert, action: \.destination.alert))
    .filePicker($store.scope(state: \.destination?.backupPicker, action: \.destination.backupPicker))
    .task {
      await store.send(.initialize).finish()
    }
  }
}

extension SettingsView {

  private var presetsSection: some View {
    Section("Presets") {
      Toggle(isOn: $store.favoritesOnTop) {
        Text("Favorites on top")
      }
      Toggle(isOn: $store.showOnlyFavorites) {
        Text("Show only favorites")
      }
      Toggle(isOn: $store.starFavoriteNames) {
        HStack {
          Text("Show")
          Image(systemName: store.favoriteSymbolName)
          Text("in favorites")
        }
      }
      Toggle(isOn: $store.sortPresetsByName) {
        Text("Presets sorted by name")
      }
      Toggle(isOn: $store.playSoundOnPresetChange) {
        Text("Play sound on preset change")
      }
    }
  }

  private var keyboardSection: some View {
    Section("Keyboard") {
      HStack {
        Text("Key labels")
        Spacer()
        Picker(
          selection: $store.keyLabels
        ) {
          ForEach(KeyLabels.allCases) { kind in
            Text(kind.rawValue)
          }
        } label: {
          Text("Key Labels")
        }
        .pickerStyle(.segmented)
      }
      Toggle(isOn: $store.showKeyNotes) {
        Text("Show key note in toolbar")
      }
      Toggle(isOn: $store.showSolfegeTags) {
        Text("Show solfège tag in toolbar")
      }
      Toggle(isOn: $store.keyboardSlides) {
        Text("Keyboard slides with touch")
      }
      VStack {
        Text("Key Width")
        Slider(value: $store.keyWidth, in: 32...96, step: 1) {
          Text("Key Width")
        } onEditingChanged: { editing in
          changingKeyWidth = editing
        }
      }
      if showFakeKeyboard && changingKeyWidth {
        KeyboardView(store: Store(initialState: .init(settingsDemo: true)) { Keyboard() })
          .transition(.opacity)
      }
    }
  }

  private var midiSection: some View {
    Section("MIDI") {
      VStack(alignment: .leading, spacing: 8) {
        HStack {
          Text("Channel")
          Spacer()
          Text(store.midiChannel == -1 ? "Any" : "\(store.midiChannel + 1)")
          Spacer()
          Stepper("", value: $store.midiChannel, in: -1...15)
            .labelsHidden()
        }
        Text(
          store.midiChannel == -1
          ? "Process any traffic regardless of MIDI channel."
          : "Only process traffic on MIDI channel \(store.midiChannel + 1)."
        )
        .font(.settingsDescription)
      }
      HStack {
        Spacer()
        MIDITrafficIndicatorView(store: store.scope(state: \.midiTrafficIndicator, action: \.midiTrafficIndicator))
        Button {
          store.send(.midiConnectionsButtonTapped)
        } label: {
          Text("^[\(store.midiDevicesCount) device](inflect: true) / ^[\(store.midiConnectedCount) connected](inflect: true)")
        }
        Spacer()
      }
      Toggle(isOn: $store.midiAutoConnect) {
        Text("New devices will auto-connect")
      }
      Toggle(isOn: $store.showMIDITrafficIndicator) {
        Text("Show MIDI activity indicator in toolbar")
      }
      Toggle(isOn: $store.showMIDINotesOnKeyboard) {
        Text("Show MIDI note activity on keyboard")
      }
      HStack {
        Text("Bluetooth MIDI")
        Spacer()
        Button {
          store.send(.bluetoothMIDILocateButtonTapped)
        } label: {
          Text("Locate")
        }
      }
      HStack {
        Text("Pitch bend range (semitones)")
        Spacer()
        Text("\(store.pitchBendRange)")
        Spacer()
        Stepper("", value: $store.pitchBendRange, in: 1...24)
          .labelsHidden()
      }
      HStack {
        Spacer()
        Button {
          store.send(.midiControllersButtonTapped)
        } label: {
          Text("MIDI Controllers")
        }
        Spacer()
        Button {
          store.send(.midiAssignmentsButtonTapped)
        } label: {
          Text("MIDI Assignments")
        }
        Spacer()
      }
      .buttonStyle(.borderless) // !!! keep from activating entire row and *both* buttons when one is touched
    }
    .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
  }

  private var tuningSection: some View {
    TuningView(store: store.scope(state: \.tuning, action: \.tuning))
  }

  private var fontsSection: some View {
    Section("Fonts") {
      Group {
          Toggle(isOn: $store.copyFileWhenInstalling) {
            VStack(alignment: .leading, spacing: 8) {
              Text("Copy SF2 files to app folder on device when adding")
              Text(
"""
Enabled is the safest option but files consume space on your device. \
Disable to link directly to files in iCloud or on external drives.
"""
              )
              .font(.settingsDescription)
            }
          }
        Toggle(isOn: $store.hideEmptyTags) {
          VStack(alignment: .leading, spacing: 8) {
            Text("Hide tags with no sound fonts")
            Text(
"""
Enable to reduce clutter in the main tags view. Tag editors will always show all tags.
"""
            )
            .font(.settingsDescription)
          }
        }
        Toggle(isOn: $store.hideBuiltinFonts) {
          VStack(alignment: .leading, spacing: 8) {
            Text("Hide built-in SF2 files")
            Text(
"""
Do not show the pre-installed sound fonts when the "All" tag is active.
"""
            )
            .font(.settingsDescription)
          }
        }
      }
    }
  }

  private var appSection: some View {
    Section("Application") {
      Group {
        Toggle(isOn: $store.showActiveVoiceCount) {
          Text("Show active voice counter")
        }
        if !isAUv3 {
#if os(iOS)
          Toggle(isOn: $store.mixWithOtherApps) {
            Text("Mix audio with other apps on device")
          }
          .onChange(of: store.mixWithOtherApps) {
            _ = audioSession.restart()
          }
          Toggle(isOn: $store.duckOtherApps) {
            Text("Reduce audio from other apps")
          }
          .disabled(store.mixWithOtherApps == false)
          .onChange(of: store.duckOtherApps) {
            _ = audioSession.restart()
          }
          Toggle(isOn: $store.backgroundProcessing) {
            Text("Background processing mode")
          }
#endif
          Toggle(isOn: $store.disableIdleTimer) {
            Text("Disable device locking while active")
          }
        }
        if !isAUv3 {
          HStack {
            VStack(alignment: .leading, spacing: 8) {
              Text("Restore to fresh install")
              Text(
"""
Removes all installed SF2 files and any customizations — same as reinstalling application.
"""
              )
              .font(.settingsDescription)
            }
            Spacer()
            Button {
              store.send(.restoreFreshInstallTapped)
            } label: {
              Text("Reinstall")
            }
          }
          HStack {
            VStack(alignment: .leading, spacing: 8) {
              Text("Create backup of database and SF2 files")
              Text(
"""
Backups are stored in the SoundFonts+ iCloud folder. Sound font files that were copied onto device are also backed up.
"""
              )
              .font(.settingsDescription)
            }
            Spacer()
            Button {
              store.send(.createBackupTapped)
            } label: {
              Text("Backup")
            }
          }
          .disabled(fileManager.cloudDocumentsDirectory() == nil)
          HStack {
            VStack(alignment: .leading, spacing: 8) {
              Text("Restore from backup")
              Text(
"""
Erases current database and SF2 files with contents of previous backup.
"""
              )
              .font(.settingsDescription)
            }
            Spacer()
            Button {
              store.send(.restoreBackupTapped)
            } label: {
              Text("Restore")
            }
          }
          .disabled(fileManager.cloudDocumentsDirectory() == nil)
        }
      }
    }
  }

  private var aboutSection: some View {
    Section("About") {
      Group {
        if !isAUv3 {
          HStack {
            Text("View change history")
            Spacer()
            Button {
              store.send(.delegate(.showChanges))
            } label: {
              Text("Changes")
            }
          }
          HStack {
            Text("View tutorial screens")
            Spacer()
            Button {
              store.send(.delegate(.showTutorial))
            } label: {
              Text("Tutorial")
            }
          }
        }
        HStack {
          Text("Version \(bundle.releaseVersionNumber)")
          Spacer()
          if !isAUv3 {
            Button {
              store.send(.reviewAppTapped)
            } label: {
              Text("Review App")
            }
          }
        }
        if !isAUv3 {
          HStack {
            Text("Contact developer (bradhowes@mac.com)")
            Spacer()
            Button {
              store.send(.contactDeveloperTapped)
            } label: {
              Image(systemName: "paperplane")
            }
          }
        }
      }
    }
  }
}

extension SettingsView {

  private var restoringProgressToast: Toast {
    Toast(role: .informational, duration: .indefinite) {
      Label {
        Text("Restoring…")
          .font(.toastLabel)
          .foregroundStyle(.teal)
      } icon: {
        ProgressView()
          .tint(.teal)
      }
    }
  }
}

private let log: Logger = .init(category: "AppSettings")

#if DEBUG

extension SettingsView {
  static var preview: some View {
    @Shared(.midi) var midi = MIDI(clientName: "Test", uniqueId: 123, midiProto: .v1_0)
    midi?.start()
    navigationBarTitleStyle()
    return VStack {
      SettingsView(
        store: Store(initialState: .init()) {
          Settings()
        },
        showFakeKeyboard: false
      )
    }
  }
}

#Preview {
  SettingsView.preview
    .environment(\.font, Font.body)
}

#endif // DEBUG
