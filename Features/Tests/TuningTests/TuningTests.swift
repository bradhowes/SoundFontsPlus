// Copyright © 2025 Brad Howes. All rights reserved.

import DependenciesTestSupport
import FeatureSupport
import Numerics
import SnapshotTesting
import SQLiteData
import Tagged
import Testing
import TestSupport

@testable import Tuning

@Suite(
  .snapshots(record: .failed)
)
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

  @Test
  func initialization() async {
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

  @Test
  func updateConfig() async {
    var config = AudioConfig.Draft(
      customTuningEnabled: true,
      customTuning: 587.3295358348153,
      presetId: 1
    )

    let store = store(config: config)
    await store.send(.standardTuningApplyPressed) {
      $0.frequency = 440.0
      $0.cents = 0
      $0.shiftA4Value = "None"
    }

    await store.receive(\.delegate, .tuningChanged(enabled: true, frequency: 440.0))

    store.state.updateConfig(&config)
    #expect(config.customTuningEnabled == true)
    #expect(config.customTuning == 440.0)

    await store.send(\.binding.enabled, false) {
      $0.enabled = false
    }

    await store.receive(\.delegate, .tuningChanged(enabled: false, frequency: 440.0))

    store.state.updateConfig(&config)
    #expect(config.customTuningEnabled == false)
    #expect(config.customTuning == 440.0)
  }

  @Test
  func standardTuningApplyPressed() async {
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

    await store.receive(\.delegate, .tuningChanged(enabled: true, frequency: 440.0))
  }

  @Test
  func scientificTuningApplyPressed() async {
    let store = store(frequency: 456.0, enabled: true)

    #expect(store.state.frequency == 456.0)
    #expect(store.state.cents == 62)

    await store.send(.scientificTuningApplyPressed) {
      $0.frequency = 432.0
      $0.cents = -32
      $0.shiftA4Value = "-"
    }

    await store.receive(\.delegate, .tuningChanged(enabled: true, frequency: 432.0))
  }

  @Test
  func bindingCents() async {
    let store = store(frequency: 456.0, enabled: true)

    await store.send(\.binding.cents, 500) {
      $0.frequency = 587.3295358348151
      $0.cents = 500
      $0.shiftA4Value = "D5"
    }

    await store.receive(\.delegate, .tuningChanged(enabled: true, frequency: 587.3295358348151))
  }

  @Test
  func centsSubmitted() async {
    let store = store(frequency: 456.0, enabled: true)

    await store.send(.centsSubmitted) {
      $0.frequency = 456.04310394454166
      $0.cents = 62
      $0.shiftA4Value = "-"
    }

    await store.receive(\.delegate, .tuningChanged(enabled: true, frequency: 456.04310394454166))
  }

  @Test
  func frequencySubmitted() async {
    let store = store(frequency: 456.0, enabled: true)
    await store.send(.frequencySubmitted)
    await store.receive(\.delegate, .tuningChanged(enabled: true, frequency: 456.0))
  }

  @Test
  func bindingEnabled() async {
    let store = store(frequency: 456.0, enabled: true)

    await store.send(\.binding.enabled, false) {
      $0.enabled = false
    }

    await store.receive(\.delegate, .tuningChanged(enabled: false, frequency: 456.0))
  }

  @Test
  func bindingFrequency() async {
    let store = store(frequency: 456.0, enabled: true)

    await store.send(\.binding.frequency, 440.0) {
      $0.frequency = 440.0
      $0.cents = 0
      $0.shiftA4Value = "None"
    }

    await store.receive(\.delegate, .tuningChanged(enabled: true, frequency: 440.0))
  }

  @Test
  func disabled() async throws {
    withDependencies {
      $0.defaultDatabase = previewDatabase()
    } operation: {
      withSnapshotTesting(record: .failed) {
        let view = Form {
          TuningView(store: Store(initialState: .init(frequency: 587.3295358348151, enabled: false)) { Tuning() })
        }
        TestSupport.assertSnapshot(matching: view)
      }
    }
  }

  @Test
  func preview() async throws {
    withDependencies {
      $0.defaultDatabase = previewDatabase()
    } operation: {
      withSnapshotTesting(record: .failed) {
        TestSupport.assertSnapshot(matching: TuningView.preview)
      }
    }
  }
}
