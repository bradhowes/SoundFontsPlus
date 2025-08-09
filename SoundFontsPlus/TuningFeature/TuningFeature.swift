// Copyright © 2025 Brad Howes. All rights reserved.

import ComposableArchitecture
import Sharing
import SwiftUI

@Reducer
public struct TuningFeature {

  @ObservableState
  public struct State: Equatable, Sendable {
    var enabled: Bool = false
    var frequency: Double = 440.0
    var cents: Int = 0
    var shiftA4Value: String = ""
    var disabled: Bool { !enabled }

    public init(config: AudioConfig.Draft) {
      self.enabled = config.customTuningEnabled
      self.frequency = config.customTuning
      self.setFrequency(config.customTuning)
    }

    public init(frequency: Double, enabled: Bool) {
      self.frequency = frequency != 0.0 ? frequency : 440.0
      self.enabled = enabled
      self.setFrequency(frequency)
    }

    mutating func setFrequency(_ frequency: Double) {
      self.frequency = frequency
      let cents = frequencyToCents(frequency)
      let clampedCents = min(max(cents, -2400.0), 2400.0)
      let transposeCents = (clampedCents / 100).rounded() * 100.0
      if transposeCents == clampedCents {
        if transposeCents == 0 {
          self.shiftA4Value = "None"
          self.frequency = 440.0
        } else {
          let note = Note.A4.offset(Int(transposeCents/100))
          self.shiftA4Value = note < Note.A4 ? note.labelWithFlats : note.labelWithSharps
        }
      } else {
        // Fractional component -- no mapping exists to a MIDI note
        self.shiftA4Value = "-"
      }

      self.cents = Int(clampedCents.rounded())
    }

    mutating func setCents(_ cents: Int) {
      self.cents = cents
      self.frequency = centsToFrequency(cents)

      let clampedCents = min(max(Double(cents), -2400.0), 2400.0)
      let transposeCents = (clampedCents / 100).rounded() * 100.0

      if transposeCents == clampedCents {
        if transposeCents == 0 {
          self.shiftA4Value = "None"
          self.frequency = 440.0
        } else {
          let note = Note.A4.offset(Int(transposeCents/100))
          print("note: \(note)")
          self.shiftA4Value = note < Note.A4 ? note.labelWithFlats : note.labelWithSharps
        }
      } else {
        // Fractional component -- no mapping exists to a MIDI note
        self.shiftA4Value = "-"
      }
    }
  }

  public enum Action: BindableAction, Equatable {
    case binding(BindingAction<State>)
    case delegate(Delegate)
    case standardTuningApplyPressed
    case scientificTuningApplyPressed
    case centsSumbmitted
    case frequencySubmitted

    public enum Delegate: Equatable {
      case tuningChanged(enabled: Bool, frequency: Double)
    }
  }

  public init() {}

  public var body: some ReducerOf<Self> {
    BindingReducer()

    Reduce { state, action in
      switch action {
      case .binding(\.cents): return setCents(&state, cents: state.cents)
      case .binding(\.frequency): return setFrequency(&state, frequency: state.frequency)
      case .binding: return .none
      case .delegate: return .none
      case .standardTuningApplyPressed: return setFrequency(&state, frequency: 440.0)
      case .scientificTuningApplyPressed: return setFrequency(&state, frequency: 432.0)
      case .centsSumbmitted: return setCents(&state, cents: state.cents)
      case .frequencySubmitted: return setFrequency(&state, frequency: state.frequency)
      }
    }
  }

  private func setCents(_ state: inout State, cents: Int) -> Effect<Action> {
    state.setCents(cents)
    return .send(.delegate(.tuningChanged(enabled: state.enabled, frequency: state.frequency)))
  }

  private func setFrequency(_ state: inout State, frequency: Double) -> Effect<Action> {
    state.setFrequency(frequency)
    return .send(.delegate(.tuningChanged(enabled: state.enabled, frequency: state.frequency)))
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
        HStack {
          Text("Shift A4 to:")
          Spacer()
          Text(store.shiftA4Value)
          Spacer()
          Stepper("", value: $store.cents, in: -2400...2400, step: 100)
            .labelsHidden()
            .disabled(store.disabled)
        }
        HStack {
          Text("Standard tuning (A4 = 440 Hz)")
          Spacer()
          Button {
            store.send(.standardTuningApplyPressed)
          } label: {
            Text("Apply")
          }
          .disabled(store.disabled)
        }
        HStack {
          Text("Scientific tuning (A4 = 432 Hz)")
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
          TextField(value: $store.cents, formatter: formatter) {
            Text("")
          }
          .textFieldStyle(.roundedBorder)
          .disableAutocorrection(true)
          .onSubmit {
            store.send(.centsSumbmitted)
          }
          .disabled(store.disabled)
        }
        HStack {
          Text("A4 Frequency (Hz):")
            .disabled(store.disabled)
          Spacer()
          TextField(value: $store.frequency, formatter: formatter) {
            Text("")
          }
          .textFieldStyle(.roundedBorder)
          .disableAutocorrection(true)
          .onSubmit {
            store.send(.frequencySubmitted)
          }
          .disabled(store.disabled)
        }
        .disabled(store.disabled)
      }
    }
    header: {
      Text("Tuning")
    }
  }
}

private func centsToFrequency(_ cents: Int) -> Double { pow(2.0, (Double(cents) / 1200.0)) * 440.0 }
private func frequencyToCents(_ frequency: Double) -> Double { log2(frequency / 440.0) * 1200.0 }

extension TuningView {
  static var preview: some View {
    Form {
      TuningView(store: Store(initialState: .init(frequency: 440.0, enabled: true)) { TuningFeature() })
    }
  }
}

#Preview {
  TuningView.preview
}
