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
public struct AppSettings {

  @Reducer
  public enum Path {
    case midiAssignments(MIDIAssignments)
    case midiConnections(MIDIConnections)
    case midiControllers(MIDIControllers)
  }

  @Reducer
  public enum Destination {
    case alert(AlertState<Alert>)

    @CasePathable
    public enum Alert {
      case disableCopyFileConfirmed
      case disableIdleTimerConfirmed
    }
  }

  @ObservableState
  public struct State: Equatable {
    public var path = StackState<Path.State>()
    @Presents public var destination: Destination.State?
    public var midiConnectCount: Int = 0
    public var midiTrafficIndicator: MIDITrafficIndicator.State
    public var tuning: Tuning.State
    public let hasMIDI: Bool

    @Shared(.backgroundProcessing) public var backgroundProcessing
    @Shared(.copyFileWhenInstalling) public var copyFileWhenInstalling
    @Shared(.disableIdleTimer) public var disableIdleTimer
    @Shared(.duckOtherApps) public var duckOtherApps
    @Shared(.favoritesOnTop) public var favoritesOnTop
    @Shared(.favoriteSymbolName) public var favoriteSymbolName
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
    @Shared(.showOnlyFavorites) public var showOnlyFavorites
    @Shared(.showSolfegeTags) public var showSolfegeTags
    @Shared(.sortPresetsByName) public var sortPresetsByName
    @Shared(.starFavoriteNames) public var starFavoriteNames

    public init(
      path: StackState<Path.State> = .init(),
      destination: Destination.State? = nil,
      midiConnectCount: Int = 0,
      midiTrafficIndicator: MIDITrafficIndicator.State = .init(tag: "Settings"),
      tuning: Tuning.State = Self.makeTuningState()
    ) {
      @Shared(.midi) var midi
      hasMIDI = midi != nil
      self.path = path
      self.destination = destination
      self.midiConnectCount = midi?.sourceConnections.count ?? midiConnectCount
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
    case delegate(Delegate)
    case destination(PresentationAction<Destination.Action>)
    case dismissButtonTapped
    case exportFilesTapped
    case hideBuiltInFilesTapped
    case importFilesTapped
    case initialize
    case midiAssignmentsButtonTapped
    case midiConnectionsButtonTapped
    case midiControllersButtonTapped
    case path(StackActionOf<Path>)
    case tuning(Tuning.Action)
    case midiConnectionCountChanged(Int)
    case midiTrafficIndicator(MIDITrafficIndicator.Action)
    case reviewAppTapped
    case unhideBuiltInFilesTapped
    case viewChangesTapped
    case viewTutorialTapped

    @CasePathable
    public enum Delegate {
      case showChanges
      case showTutorial
    }
  }

  public init() {}

  public var body: some ReducerOf<Self> {
    BindingReducer()

    Scope(state: \.midiTrafficIndicator, action: \.midiTrafficIndicator) { MIDITrafficIndicator() }
    Scope(state: \.tuning, action: \.tuning) { Tuning() }

    Reduce { state, action in
      log.info("state action: \(action)")
      switch action {

      case .binding(\.keyWidth):
        return updateKeyWidth(&state)

      case .binding(\.copyFileWhenInstalling):
        log.info("copyFileWhenInstalling value: \(state.copyFileWhenInstalling)")
        if !state.copyFileWhenInstalling {
          state.$copyFileWhenInstalling.withLock { $0 = true }
          state.destination = .alert(.confirmDisableCopyFile(action: .disableCopyFileConfirmed))
        }
        return .none

      case .binding(\.disableIdleTimer):
        log.info("disableIdleTimer value: \(state.disableIdleTimer)")
        if state.disableIdleTimer {
          state.$disableIdleTimer.withLock { $0 = false }
          state.destination = .alert(.confirmDisableIdleTimer(action: .disableIdleTimerConfirmed))
        }
        return .none

      case .destination(.presented(.alert(.disableCopyFileConfirmed))):
        state.$copyFileWhenInstalling.withLock { $0 = false }
        return .none

      case .destination(.presented(.alert(.disableIdleTimerConfirmed))):
        state.$disableIdleTimer.withLock { $0 = true }
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

      case .midiConnectionCountChanged(let count):
        state.midiConnectCount = count
        return .none

      case .midiControllersButtonTapped:
        state.path.append(.midiControllers(MIDIControllers.State()))
        return .none

      case let .tuning(.delegate(.tuningChanged(enabled, frequency))):
        return tuningChanged(&state, enabled: enabled, frequency: frequency)

      case .viewChangesTapped:
        return .send(.delegate(.showChanges))

      case .viewTutorialTapped:
        return .send(.delegate(.showTutorial))

      default:
        return .none
      }
    }
    .forEach(\.path, action: \.path)
    .ifLet(\.destination, action: \.destination)
  }

  private enum CancelId: String {
    case appSettingsMonitorMIDIConnections
  }
}

extension AppSettings {

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
    @Shared(.midi) var midi
    guard let midi else { return .none }
    return .publisher {
      midi.activeConnectionsCountPublisher
        .map { .midiConnectionCountChanged(Int($0)) }
    }.cancellable(id: CancelId.appSettingsMonitorMIDIConnections)
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

extension AppSettings.Path.State: Equatable {}
extension AppSettings.Destination.State: Equatable {}
extension AppSettings.Destination.State: _EphemeralState {
  public typealias Action = Alert
}

public struct AppSettingsView: View {
  @Bindable private var store: StoreOf<AppSettings>
  @State private var changingKeyWidth: Bool = false
  @Shared(.isAUv3) private var isAUv3
  private let showFakeKeyboard: Bool
  private let bundle = Bundle.main

  public init(store: StoreOf<AppSettings>, showFakeKeyboard: Bool) {
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
        appSection
        aboutSection
      }
      .font(.settings)
      .formStyle(.grouped)
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
    .alert($store.scope(state: \.destination?.alert, action: \.destination.alert))
    .task {
      await store.send(.initialize).finish()
    }
  }
}

extension AppSettingsView {

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
    .circledCheckMarkToggleStyle()
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
      .circledCheckMarkToggleStyle()
      Toggle(isOn: $store.showSolfegeTags) {
        Text("Show solfège tag in toolbar")
      }
      .circledCheckMarkToggleStyle()
      Toggle(isOn: $store.keyboardSlides) {
        Text("Keyboard slides with touch")
      }
      .circledCheckMarkToggleStyle()
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
      HStack {
        Text("Channel:")
        Spacer()
        Stepper(store.midiChannel == -1 ? "Any" : "\(store.midiChannel + 1)", value: $store.midiChannel, in: -1...15)
      }
      HStack {
        Spacer()
        MIDITrafficIndicatorView(store: store.scope(state: \.midiTrafficIndicator, action: \.midiTrafficIndicator))
        Button {
          store.send(.midiConnectionsButtonTapped)
        } label: {
          Text("^[\(store.midiConnectCount) connection](inflect: true)")
        }
        Spacer()
      }
      Toggle(isOn: $store.midiAutoConnect) {
        Text("New device auto-connect")
      }
      .circledCheckMarkToggleStyle()
      HStack {
        Text("Bluetooth MIDI")
        Spacer()
        Button {
          store.send(.bluetoothMIDILocateButtonTapped)
        } label: {
          Text("Locate")
        }
      }
      Stepper(
        "Pitch bend range (semitones): \(store.pitchBendRange)",
        value: $store.pitchBendRange,
        in: 1...24
      )
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

  private var appSection: some View {
    Section("Application") {
      Group {
        Toggle(isOn: $store.showActiveVoiceCount) {
          Text("Show active voice counter")
        }
        .circledCheckMarkToggleStyle()
        if !isAUv3 {
#if os(iOS)
          Toggle(isOn: $store.mixWithOtherApps) {
            Text("Mix audio with other apps on device")
          }
          .circledCheckMarkToggleStyle()
          Toggle(isOn: $store.duckOtherApps) {
            Text("Reduce audio from other apps")
          }
          .circledCheckMarkToggleStyle()
          .disabled(store.mixWithOtherApps == false)
          Toggle(isOn: $store.backgroundProcessing) {
            Text("Background processing mode")
          }
          .circledCheckMarkToggleStyle()
#endif
          Toggle(isOn: $store.copyFileWhenInstalling) {
            VStack(alignment: .leading) {
              Text("Copy SF2 files to app folder on device when adding.")
              Text(
"""
Enabled is the safest option, but it takes up space on your device. \
Disable to link directly to files in iCloud or on external drives.
"""
              )
              .font(.settingsDescription)
            }
          }
          .circledCheckMarkToggleStyle()
          Toggle(isOn: $store.disableIdleTimer) {
            Text("Disable device locking while active")
          }
          .circledCheckMarkToggleStyle()
        }
        HStack {
          Text("Hide built-in SF2 files")
          Spacer()
          Button {
            store.send(.hideBuiltInFilesTapped)
          } label: {
            Text("Hide")
          }
        }
        HStack {
          Text("Unhide built-in SF2 files")
          Spacer()
          Button {
            store.send(.unhideBuiltInFilesTapped)
          } label: {
            Text("Show")
          }
        }
        if !isAUv3 {
          HStack {
            Text("Export all internal files to local SoundFonts folder on device.")
            Spacer()
            Button {
              store.send(.exportFilesTapped)
            } label: {
              Text("Export")
            }
          }
          HStack {
            Text("Import all SF2 files in local SoundFonts folder on device.")
            Spacer()
            Button {
              store.send(.importFilesTapped)
            } label: {
              Text("Import")
            }
          }
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
              store.send(.viewChangesTapped)
            } label: {
              Text("Changes")
            }
          }
          HStack {
            Text("View tutorial screens")
            Spacer()
            Button {
              store.send(.viewTutorialTapped)
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

extension AppSettingsView {
  static var preview: some View {
    @Shared(.midi) var midi = MIDI(clientName: "Test", uniqueId: 123, midiProto: .v1_0)
    midi?.start()
    navigationBarTitleStyle()
    return VStack {
      AppSettingsView(
        store: Store(initialState: .init()) {
          AppSettings()
        },
        showFakeKeyboard: false
      )
    }
  }
}

private let log = Logger(category: "AppSettings")

#Preview {
  AppSettingsView.preview
}
