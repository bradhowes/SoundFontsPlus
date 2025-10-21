// Copyright © 2025 Brad Howes. All rights reserved.

import DependenciesTestSupport
import FeatureSupport
import Numerics
import SnapshotTesting
import Testing
import TestSupport

@testable import Tuning

@Suite
@MainActor
struct TuningTests {

  fileprivate func store(config: AudioConfig.Draft) -> TestStoreOf<Tuning> {
    TestStoreOf<Tuning>(initialState: .init(config: config)) {
      Tuning()
    }
  }

  fileprivate func store(frequency: Double, enabled: Bool) -> TestStoreOf<Tuning> {
    TestStoreOf<Tuning>(initialState: .init(frequency: frequency, enabled: enabled)) {
      Tuning()
    }
  }

  @Test func initialization() async {
    let config = AudioConfig.Draft(
      customTuningEnabled: true,
      customTuning: 587.3295358348153,
      presetId: 1
    )

    let store = store(config: config)

    #expect(store.state.frequency.isApproximatelyEqual(to: 587.329535834815))
    #expect(store.state.cents == 500)
    #expect(store.state.shiftA4Value == "D5")
    #expect(store.state.enabled)
  }

  @Test func standardTuningApplyPressed() async {
    let store = store(frequency: 329.62755691287, enabled: true)

    #expect(store.state.frequency.isApproximatelyEqual(to: 329.62755691287))
    #expect(store.state.cents == -500)
    #expect(store.state.shiftA4Value == "E4")
    #expect(store.state.enabled)

    await store.send(.standardTuningApplyPressed) {
      $0.frequency = 440.0
      $0.cents = 0
      $0.shiftA4Value = "None"
    }

    await store.receive(.delegate(.tuningChanged(enabled: true, frequency: 440.0)))
  }

  @Test func scientificTuningApplyPressed() async {
    let store = store(frequency: 456.0, enabled: true)

    #expect(store.state.frequency == 456.0)
    #expect(store.state.cents == 62)

    await store.send(.scientificTuningApplyPressed) {
      $0.frequency = 432.0
      $0.cents = -32
      $0.shiftA4Value = "-"
    }

    await store.receive(.delegate(.tuningChanged(enabled: true, frequency: 432.0)))
  }
}
