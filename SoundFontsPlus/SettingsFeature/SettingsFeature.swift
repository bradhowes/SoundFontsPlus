// Copyright © 2025 Brad Howes. All rights reserved.

import ComposableArchitecture
@preconcurrency import MorkAndMIDI
import Sharing
import SwiftUI

@Reducer
public struct SettingsFeature {

  @Reducer
  public enum Path {
    case midiAssignments(MIDIAssignmentsFeature)
    case midiConnections(MIDIConnectionsFeature)
    case midiControllers(MIDIControllersFeature)
  }

  @ObservableState
  public struct State {
    var path = StackState<Path.State>()
    var midiConnectCount: Int = 0
    let midi: MIDI?
    @Shared(.keyWidth) var keyWidth
    @Shared(.keyboardSlides) var keyboardSlides
    @Shared(.showSolfegeTags) var showSolfegeTags
    @Shared(.keyLabels) var keyLabels
    @Shared(.midiAutoConnect) var midiAutoConnect
    @Shared(.midiChannel) var midiChannel
    @Shared(.backgroundProcessing) var backgroundProcessing
    @Shared(.pitchBendRange) var pitchBendRange
    @Shared(.favoritesOnTop) var favoritesOnTop
    @Shared(.showOnlyFavorites) var showOnlyFavorites
    @Shared(.starFavoriteNames) var starFavoriteNames
    @Shared(.favoriteSymbolName) var favoriteSymbolName
    @Shared(.playSoundOnPresetChange) var playSoundOnPresetChange

    var tuning: TuningFeature.State

    public init(midi: MIDI? = nil) {
      self.midi = midi
      self.midiConnectCount = midi?.sourceConnections.count ?? 0
      @Shared(.globalTuningEnabled) var tuningEnabled
      @Shared(.globalTuning) var frequency
      self.tuning = .init(frequency: frequency, enabled: tuningEnabled)
    }
  }

  public enum Action: BindableAction {
    case binding(BindingAction<State>)
    case bluetoothMIDILocateButtonTapped
    case dismissButtonTapped
    case midiAssignmentsButtonTapped
    case midiConnectionsButtonTapped
    case midiControllersButtonTapped
    case path(StackActionOf<Path>)
    case task
    case tuning(TuningFeature.Action)
    case midiConnectionCountChanged(Int)
  }

  public init() {}

  public var body: some ReducerOf<Self> {
    BindingReducer()
    Scope(state: \.tuning, action: \.tuning) { TuningFeature() }
    Reduce { state, action in
      switch action {
      case .binding(\.keyWidth): return updateKeyWidth(&state)
      case .binding: return .none
      case .bluetoothMIDILocateButtonTapped: return .none
      case .dismissButtonTapped: return dismissButtonTapped(&state)
      case .midiAssignmentsButtonTapped:
        if state.midi != nil {
          state.path.append(.midiAssignments(MIDIAssignmentsFeature.State()))
        }
        return .none
      case .midiConnectionsButtonTapped:
        if let midi = state.midi {
          state.path.append(.midiConnections(MIDIConnectionsFeature.State(midi: midi)))
        }
        return .none
      case .midiConnectionCountChanged(let count):
        state.midiConnectCount = count
        return .none
      case .midiControllersButtonTapped:
        if state.midi != nil {
          state.path.append(.midiControllers(MIDIControllersFeature.State()))
        }
        return .none
      case .path: return .none
      case .task: return initialize(&state)
      case .tuning: return .none
      }
    }
    .forEach(\.path, action: \.path)
  }

  private enum CancelId {
    case monitorActiveConnections
  }
}

private extension SettingsFeature {

  func dismissButtonTapped(_ state: inout State) -> Effect<Action> {
    @Dependency(\.dismiss) var dismiss
    return .run { _ in await dismiss() }
  }

  func initialize(_ state: inout State) -> Effect<Action> {
    if let midi = state.midi {
      return .run { send in
        for await count in midi.publisher(for: \.activeConnections)
          .buffer(size: 1, prefetch: .byRequest, whenFull: .dropOldest)
          .map({ $0.count })
          .values {
          await send(.midiConnectionCountChanged(count))
        }
      }
    }
    return .none
  }

  func updateKeyWidth(_ state: inout State) -> Effect<Action> {
    var value = state.keyWidth
    for stop in [48.0, 64.0, 80.0] where Swift.abs(value - stop) < 3.0 {
      value = stop
      break
    }

    return updateShared(.keyWidth, value: value)
  }

  func updateShared<T>(_ key: AppStorageKey<T>.Default, value: T) -> Effect<Action> {
    @Shared(key) var store
    $store.withLock { $0 = value }
    return .none
  }
}

public struct SettingsView: View {
  @Bindable private var store: StoreOf<SettingsFeature>
  @State private var changingKeyWidth: Bool = false
  private let showFakeKeyboard: Bool

  public init(store: StoreOf<SettingsFeature>, showFakeKeyboard: Bool) {
    self.store = store
    self.showFakeKeyboard = showFakeKeyboard
  }

  public var body: some View {
    NavigationStack(path: $store.scope(state: \.path, action: \.path)) {
      Form {
        presetsSection
        keyboardSection
        if store.midi != nil {
          midiSection
        }
        tuningSection
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
      }
    }
    .task {
      await store.send(.task).finish()
    }
  }

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
      Toggle(isOn: $store.showSolfegeTags) {
        Text("Solfège tags")
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
      HStack {
        Text("Bluetooth MIDI")
        Spacer()
        Button {
          store.send(.bluetoothMIDILocateButtonTapped)
        } label: {
          Text("Locate")
        }
      }
      Toggle(isOn: $store.backgroundProcessing) {
        Text("Background processing mdoe")
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
    }
  }

  private var tuningSection: some View {
    TuningView(store: Store(initialState: store.tuning) { TuningFeature() })
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
