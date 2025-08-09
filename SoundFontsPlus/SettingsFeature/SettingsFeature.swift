// Copyright © 2025 Brad Howes. All rights reserved.

import ComposableArchitecture
import Sharing
import SwiftUI

@Reducer
public struct SettingsFeature {

  @ObservableState
  public struct State: Equatable, Sendable {
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
    var tuning: TuningFeature.State

    public init() {
      @Shared(.globalTuningEnabled) var tuningEnabled
      @Shared(.globalTuning) var frequency
      self.tuning = .init(frequency: frequency, enabled: tuningEnabled)
    }
  }

  public enum Action: BindableAction, Equatable {
    case binding(BindingAction<State>)
    case bluetoothMIDILocateButtonTapped
    case dismissButtonTapped
    case midiAssignmentsButtonTapped
    case midiConnectionsButtonTapped
    case midiControllersButtonTapped
    case tuning(TuningFeature.Action)
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
      case .midiAssignmentsButtonTapped: return .none
      case .midiConnectionsButtonTapped: return .none
      case .midiControllersButtonTapped: return .none
      case .tuning: return .none
      }
    }
  }

  func dismissButtonTapped(_ state: inout State) -> Effect<Action> {
    @Dependency(\.dismiss) var dismiss
    return .run { _ in await dismiss() }
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
  @State private var store: StoreOf<SettingsFeature>
  @State private var changingKeyWidth: Bool = false
  private let showFakeKeyboard: Bool

  public init(store: StoreOf<SettingsFeature>, showFakeKeyboard: Bool) {
    self.store = store
    self.showFakeKeyboard = showFakeKeyboard
  }

  public var body: some View {
    NavigationStack {
      Form {
        displaySection
        keyboardSection
        midiSection
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
    }
  }

  private var displaySection: some View {
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
          Text("1 connection")
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
