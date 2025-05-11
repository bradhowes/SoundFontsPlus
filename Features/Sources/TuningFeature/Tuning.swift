import ComposableArchitecture
import Sharing
import SwiftUI
import Utils

@Reducer
public struct TuningFeature {

  @ObservableState
  public struct State: Equatable {
    var enabled: Bool = false
    var tuning: Double = 0.0
    var tuningCents: Double = 0
    var tuningFrequency: Double = 440.0
    var shiftA4Value: String = ""
    var disabled: Bool { !enabled }

    public init(cents: Double, enabled: Bool) {
      self.tuning = cents
      self.enabled = enabled
      self.setTuningCents(cents)
    }

    mutating func setTuningCents(_ cents: Double) {
      let clampedCents = min(max(cents, -2400.0), 2400.0)
      let transposeCents = (clampedCents / 100).rounded() * 100.0
      if transposeCents == clampedCents {
        // No fractional component -- map to a note value
        if transposeCents == 0 {
          self.shiftA4Value = "None"
          self.tuning = 0.0
        } else {
          let note = Note.A4.offset(Int(transposeCents/100))
          self.shiftA4Value = note < Note.A4 ? note.labelWithFlats : note.labelWithSharps
        }
      } else {
        // Fractional component -- no mapping exists to a MIDI note
        self.shiftA4Value = "-"
      }

      self.tuningFrequency = centsToFrequency(clampedCents)
      self.tuningCents = clampedCents
      self.tuning = clampedCents
    }
  }

  public enum Action: BindableAction, Equatable {
    case binding(BindingAction<State>)
    case delegate(Delegate)
    case standardTuningApplyPressed
    case scientificTuningApplyPressed
    case tuningCentsSumbmitted
    case tuningFrequencySubmitted

    public enum Delegate: Equatable {
      case tuningChanged(enabled: Bool, cents: Double)
    }
  }

  public init() {}

  public var body: some ReducerOf<Self> {
    BindingReducer()

    Reduce { state, action in
      switch action {
      case .binding(\.tuning): return setTuningCents(&state, cents: state.tuning)
      case .binding: return .none
      case .delegate: return .none
      case .standardTuningApplyPressed: return setTuningCents(&state, cents: 0)
      case .scientificTuningApplyPressed: return setTuningCents(&state, cents: frequencyToCents(432.0))
      case .tuningCentsSumbmitted: return setTuningCents(&state, cents: state.tuningCents)
      case .tuningFrequencySubmitted: return setTuningCents(&state, cents: frequencyToCents(state.tuningFrequency))
      }
    }
  }

  private func setTuningCents(_ state: inout State, cents: Double) -> Effect<Action> {
    state.setTuningCents(cents)
    return .send(.delegate(.tuningChanged(enabled: state.enabled, cents: state.tuningCents)))
  }
}

public struct TuningView: View {
  @State private var store: StoreOf<TuningFeature>

  @State private var formatter: NumberFormatter = {
    var formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    return formatter
  }()

  public init(store: StoreOf<TuningFeature>) {
    self.store = store
  }

  public var body: some View {
    Section {
      Group {
        Toggle(isOn: $store.enabled) {
          Text("Enabled")
        }
        Stepper("Shift A4 to: \(store.shiftA4Value)", value: $store.tuning, in: -2400...2400, step: 100)
          .disabled(store.disabled)
        HStack {
          Text("Standard tuning\n(A4 = 440 Hz)")
          Spacer()
          Button {
            store.send(.standardTuningApplyPressed)
          } label: {
            Text("Apply")
          }
          .disabled(store.disabled)
        }
        HStack {
          Text("Scientific tuning\n(A4 = 432 Hz)")
          Spacer()
          Button {
            store.send(.scientificTuningApplyPressed)
          } label: {
            Text("Apply")
          }
          .disabled(store.disabled)
        }
        HStack {
          Text("Cents (± 2400):")
          Spacer()
          TextField(value: $store.tuningCents, formatter: formatter) {
            Text("")
          }
          .textFieldStyle(.roundedBorder)
          .disableAutocorrection(true)
          .onSubmit {
            store.send(.tuningCentsSumbmitted)
          }
          .disabled(store.disabled)
        }
        HStack {
          Text("A4 Frequency (Hz):")
          Spacer()
          TextField(value: $store.tuningFrequency, formatter: formatter) {
            Text("")
          }
          .textFieldStyle(.roundedBorder)
          .disableAutocorrection(true)
          .onSubmit {
            store.send(.tuningFrequencySubmitted)
          }
          .disabled(store.disabled)
        }
      }
    }
    header: {
      Text("Tuning")
    }
  }
}

private func centsToFrequency(_ cents: Double) -> Double { pow(2.0, (cents / 1200.0)) * 440.0 }
private func frequencyToCents(_ frequency: Double) -> Double { log2(frequency / 440.0) * 1200.0 }

extension TuningView {
  static var preview: some View {
    Form {
      TuningView(store: Store(initialState: .init(cents: 0.0, enabled: true)) { TuningFeature() })
    }
  }
}

#Preview {
  TuningView.preview
}
