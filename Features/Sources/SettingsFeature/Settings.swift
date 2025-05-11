import ComposableArchitecture
import KeyboardFeature
import Sharing
import SwiftUI
import TuningFeature
import Utils

@Reducer
public struct SettingsFeature {

  @ObservableState
  public struct State: Equatable {
    @Shared(.keyWidth) var keyWidth
    @Shared(.keyboardSlides) var keyboardSlides
    @Shared(.showSolfegeTags) var showSolfegeTags
    @Shared(.keyLabels) var keyLabels
    @Shared(.midiChannel) var midiChannel
    @Shared(.midiAutoConnect) var midiAutoConnect
    @Shared(.backgroundProcessing) var backgroundProcessing
    @Shared(.pitchBendRange) var pitchBendRange

    var tuning: TuningFeature.State

    public init() {
      @Shared(.globalTuningCents) var tuningCents
      @Shared(.globalTuningEnabled) var tuningEnabled
      self.tuning = TuningFeature.State(cents: tuningCents, enabled: tuningEnabled)
    }
  }

  public enum Action: BindableAction, Equatable {
    case binding(BindingAction<State>)
    case bluetoothMIDILocateButtonTapped
    case dismissButtonTapped
    case midiConnectionsButtonTapped
    case midiControllersButtonTapped
    case midiAssignmentsButtonTapped
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
      case .midiConnectionsButtonTapped: return .none
      case .midiControllersButtonTapped: return .none
      case .midiAssignmentsButtonTapped: return .none
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
    for stop in [48.0, 64.0, 80.0] {
      if Swift.abs(value - stop) < 3.0 {
        value = stop
        break
      }
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

  public init(store: StoreOf<SettingsFeature>) {
    self.store = store
  }

  public var body: some View {
    Form {
      keyboardSection
      midiSection
      tuningSection
    }
    .formStyle(.grouped)
    .navigationTitle("Settings")
    .toolbar {
      ToolbarItem(placement: .confirmationAction) {
        Button("Dismiss") { store.send(.dismissButtonTapped, animation: .default) }
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
      VStack {
        Text("Key Width")
        Slider(value: $store.keyWidth,
               in: 32...96,
               step: 1
        )
      }
      Toggle(isOn: $store.keyboardSlides) {
        Text("Slide keyboard with touch")
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
    VStack {
      SettingsView(store: Store(initialState: .init()) {
        SettingsFeature()
      })
      KeyboardView(store: Store(initialState: .init()) { KeyboardFeature() })
    }
  }
}

#Preview {
  SettingsView.preview
}
