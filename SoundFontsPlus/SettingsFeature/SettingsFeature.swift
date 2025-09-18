// Copyright © 2025 Brad Howes. All rights reserved.

import Combine
import ComposableArchitecture
import Sharing
import SwiftUI

private let log = Logger(category: "SettingsFeature")

@Reducer
public struct SettingsFeature {

  @Reducer(state: .equatable)
  public enum Path {
    case midiAssignments(MIDIAssignmentsFeature)
    case midiConnections(MIDIConnectionsFeature)
    case midiControllers(MIDIControllersFeature)
    case tutorial(TutorialFeature)
  }

  @Reducer(state: .equatable)
  public enum Destination: Equatable {
    case alert(AlertState<Alert>)

    @CasePathable
    public enum Alert {
      case disableCopyFileConfirmed
      case disableIdleTImerConfirmed
    }
  }

  @ObservableState
  public struct State: Equatable {
    var path = StackState<Path.State>()
    @Presents var destination: Destination.State?
    var midiConnectCount: Int = 0

    @Shared(.backgroundProcessing) var backgroundProcessing
    @Shared(.copyFileWhenInstalling) var copyFileWhenInstalling
    @Shared(.disableIdleTimer) var disableIdleTimer
    @Shared(.favoritesOnTop) var favoritesOnTop
    @Shared(.favoriteSymbolName) var favoriteSymbolName
    @Shared(.keyboardSlides) var keyboardSlides
    @Shared(.keyLabels) var keyLabels
    @Shared(.keyWidth) var keyWidth
    @Shared(.midiAutoConnect) var midiAutoConnect
    @Shared(.midiChannel) var midiChannel
    @Shared(.pitchBendRange) var pitchBendRange
    @Shared(.playSoundOnPresetChange) var playSoundOnPresetChange
    @Shared(.showActiveVoiceCount) var showActiveVoiceCount
    @Shared(.showKeyNotes) var showKeyNotes
    @Shared(.showOnlyFavorites) var showOnlyFavorites
    @Shared(.showSolfegeTags) var showSolfegeTags
    @Shared(.starFavoriteNames) var starFavoriteNames

    var midiTrafficIndicator: MIDITrafficIndicatorFeature.State = .init(tag: "Settings")
    var tuning: TuningFeature.State

    let hasMIDI: Bool
    public init() {
      @Shared(.midi) var midi
      hasMIDI = midi != nil
      self.midiConnectCount = midi?.sourceConnections.count ?? 0
      @Shared(.globalTuningEnabled) var tuningEnabled
      @Shared(.globalTuning) var frequency
      self.tuning = .init(frequency: frequency, enabled: tuningEnabled)
    }
  }

  public enum Action: BindableAction {
    case binding(BindingAction<State>)
    case bluetoothMIDILocateButtonTapped
    case contactDeveloperTapped
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
    case tuning(TuningFeature.Action)
    case midiConnectionCountChanged(Int)
    case midiTrafficIndicator(MIDITrafficIndicatorFeature.Action)
    case reviewAppTapped
    case unhideBuiltInFilesTapped
    case viewChangesTapped
    case viewTutorialTapped
  }

  public init() {}

  public var body: some ReducerOf<Self> {
    BindingReducer()

    Scope(state: \.tuning, action: \.tuning) { TuningFeature() }
    Scope(state: \.midiTrafficIndicator, action: \.midiTrafficIndicator) { MIDITrafficIndicatorFeature() }

    Reduce { state, action in
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
          state.destination = .alert(.confirmDisableIdleTimer(action: .disableIdleTImerConfirmed))
        }
        return .none

      case .binding:
        return .none

      case .bluetoothMIDILocateButtonTapped:
        return .none

      case .contactDeveloperTapped:
        return .none

      case .destination(.presented(.alert(.disableCopyFileConfirmed))):
        state.$copyFileWhenInstalling.withLock { $0 = false }
        return .none

      case .destination(.presented(.alert(.disableIdleTImerConfirmed))):
        state.$disableIdleTimer.withLock { $0 = true }
        return .none

      case .destination:
        return .none

      case .dismissButtonTapped:
        return dismissButtonTapped(&state)

      case .exportFilesTapped:
        return .none

      case .hideBuiltInFilesTapped:
        return .none

      case .importFilesTapped:
        return .none

      case .initialize:
        return initialize(&state)

      case .midiAssignmentsButtonTapped:
        state.path.append(.midiAssignments(MIDIAssignmentsFeature.State()))
        return .none

      case .midiConnectionsButtonTapped:
        state.path.append(.midiConnections(MIDIConnectionsFeature.State()))
        return .none

      case .midiConnectionCountChanged(let count):
        state.midiConnectCount = count
        return .none

      case .midiControllersButtonTapped:
        state.path.append(.midiControllers(MIDIControllersFeature.State()))
        return .none

      case .midiTrafficIndicator:
        return .none

      case .path:
        return .none

      case .reviewAppTapped:
        return .none

      case .tuning:
        return .none

      case .unhideBuiltInFilesTapped:
        return .none

      case .viewChangesTapped:
        return .none

      case .viewTutorialTapped:
        state.path.append(.tutorial(TutorialFeature.State()))
        return .none

      }
    }
    .forEach(\.path, action: \.path)
    .ifLet(\.destination, action: \.destination)
  }

  private enum CancelId {
    case monitorMIDIConnections
  }
}

extension SettingsFeature.Destination.State: _EphemeralState {
  public typealias Action = Alert
}

extension SettingsFeature {

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
    return .run { send in
      for await count in midi.publisher(for: \.activeConnections)
        .buffer(size: 1, prefetch: .byRequest, whenFull: .dropOldest)
        .map({ $0.count })
        .values {
        await send(.midiConnectionCountChanged(count))
      }
    }.cancellable(id: CancelId.monitorMIDIConnections)
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

public struct SettingsView: View {
  @Bindable private var store: StoreOf<SettingsFeature>
  @State private var changingKeyWidth: Bool = false
  private let showFakeKeyboard: Bool
  private let bundle = Bundle.main

  public init(store: StoreOf<SettingsFeature>, showFakeKeyboard: Bool) {
    self.store = store
    self.showFakeKeyboard = showFakeKeyboard
  }

  public var body: some View {
    NavigationStack(path: $store.scope(state: \.path, action: \.path)) {
      Form {
        presetsSection
        keyboardSection
        if store.hasMIDI {
          midiSection
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
        }
      }
      .animation(.smooth, value: changingKeyWidth)
    } destination: { store in
      switch store.case {
      case .midiAssignments(let store): MIDIAssignmentsView(store: store)
      case .midiConnections(let store): MIDIConnectionsView(store: store)
      case .midiControllers(let store): MIDIControllersView(store: store)
      case .tutorial(let store): TutorialFeatureView(store: store)
      }
    }
    .alert($store.scope(state: \.destination?.alert, action: \.destination.alert))
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
        KeyboardView(store: Store(initialState: .init(settingsDemo: true)) { KeyboardFeature() })
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
  }

  private var tuningSection: some View {
    TuningView(store: Store(initialState: store.tuning) { TuningFeature() })
  }

  private var appSection: some View {
    Section("Application") {
      Group {
        Toggle(isOn: $store.showActiveVoiceCount) {
          Text("Show active voice counter")
        }
        .circledCheckMarkToggleStyle()
        Toggle(isOn: $store.backgroundProcessing) {
          Text("Background processing mode")
        }
        .circledCheckMarkToggleStyle()
        Toggle(isOn: $store.copyFileWhenInstalling) {
          Text("Copy SF2 files to app folder when adding")
        }
        .circledCheckMarkToggleStyle()
        Toggle(isOn: $store.disableIdleTimer) {
          Text("Disable device locking while active")
        }
        .circledCheckMarkToggleStyle()
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

  private var aboutSection: some View {
    Section("About") {
      Group {
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
        HStack {
          Text("Version \(bundle.releaseVersionNumber)")
          Spacer()
          Button {
            store.send(.reviewAppTapped)
          } label: {
            Text("Review App")
          }
        }
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

extension SettingsView {
  static var preview: some View {
    navigationBarTitleStyle()
    return VStack {
      SettingsView(
        store: Store(initialState: .init()) {
          SettingsFeature()
        },
        showFakeKeyboard: false
      )
    }
  }
}

#Preview {
  SettingsView.preview
}
