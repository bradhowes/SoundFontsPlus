// Copyright © 2025 Brad Howes. All rights reserved.

import AUv3Controls
import DependenciesTestSupport
import FeatureSupport
import Numerics
import SnapshotTesting
import SQLiteData
import Testing
import TestSupport

@testable import DelayEffect

@Suite(
  .dependencies {
    $0.defaultDatabase = TestSupport.testDatabase(seeder: addDelayConfigs)
    $0.continuousClock = TestClock()
    $0.debounceDurations = .testValue
    $0.uuid = .incrementing
  },
  .snapshots(record: .failed)
)
@MainActor
struct DelayEffectTests {
  @Shared(.delayLockEnabled) var delayLockEnabled = false

  fileprivate let device = MockDelayDevice()

  func store() -> TestStoreOf<DelayEffect> {
    TestStoreOf<DelayEffect>(initialState: .init(activePresetId: nil)) {
      DelayEffect()
    } withDependencies: {
      $0.delayDevice = .init(effect: nil, setConfig: { _, config in Task { await device.setConfig(config) } })
    }
  }

  func initialized(_ closure: (_ store: TestStoreOf<DelayEffect>) async throws -> Void) async throws {
    let store = store()
    await store.send(\.activePresetIdChanged, 1) {
      $0.activePresetId = 1
      $0.config = DelayConfig.Draft(DelayConfig.with(presetId: 1)!)
    }
    await store.receive(\.enabled.setValue, true) { $0.enabled.isOn = true }
    await store.receive(\.time.setValueSilently, 0.5)
    await store.receive(\.feedback.setValueSilently, 80.0) {
      $0.config.feedback = 25.0
      $0.dirty = true
    }
    await store.receive(\.cutoff.setValueSilently, 8000.0) { $0.config.cutoff = 12000.0 }
    await store.receive(\.wetDryMix.setValueSilently, 50.0)

    await store.receive(\.time.track.valueChanged, 0.5)
    await store.receive(\.feedback.track.valueChanged, 80.0) {
      $0.config.feedback = 80.0
      $0.feedback.track.norm = 0.9
    }
    await store.receive(\.cutoff.track.valueChanged, 8000.0) {
      $0.config.cutoff = 7999.999999999999
      $0.cutoff.track.norm = 0.6625027172679943
    }
    await store.receive(\.wetDryMix.track.valueChanged, 50.0)

    try await closure(store)

    if store.state.dirty {
      await store.send(.deinitialize) { $0.dirty = false }
    } else {
      await store.send(.deinitialize)
    }
  }

  @Test
  func initialization() async throws {
    try await initialized { store in
      #expect(store.state.wetDryMix.value.isApproximatelyEqual(to: 50.0))
    }
    #expect(await device.getTimesChanged() == 2)
  }

  @Test
  func enabledToggled() async throws {
    @Dependency(\.continuousClock) var clock
    let testClock = clock as! TestClock<Duration>
    @Dependency(\.debounceDurations) var debounceDurations

    try await initialized { store in
      #expect(store.state.config.id == 1)
      #expect(store.state.config.enabled == true)

      await store.send(.enabled(.toggleTapped(false))) {
        $0.config.presetId = store.state.activePresetId!
        $0.config.enabled = false
        $0.enabled.isOn = false
        $0.dirty = true
      }

      await testClock.advance(by: debounceDurations.effectsDisplayUpdates)
      await store.receive(\.updateDebounced)

      var config = DelayConfig.Draft(
        time: store.state.config.time,
        feedback: store.state.config.feedback,
        cutoff: store.state.config.cutoff,
        wetDryMix: store.state.config.wetDryMix,
        enabled: false,
        presetId: store.state.config.presetId
      )
      config.id = 1

      await testClock.advance(by: debounceDurations.effectsConfigurationSaves)
      await store.receive(\.saveDebounced) {
        $0.config = config
        $0.dirty = false
      }
    }

    #expect(await device.getTimesChanged() == 3)
  }

  @Test
  func wetDryMix() async throws {
    @Dependency(\.continuousClock) var clock
    let testClock = clock as! TestClock<Duration>
    @Dependency(\.debounceDurations) var debounceDurations

    try await initialized { store in

      await store.send(.wetDryMix(.setValue(40)))
      await store.receive(\.wetDryMix) { $0.wetDryMix.title.formattedValue = "40" }
      await store.receive(\.wetDryMix.track.valueChanged, 40.0) {
        $0.config.wetDryMix = 40.0
        $0.wetDryMix.track.norm = 0.4
        $0.dirty = true
      }

      await testClock.advance(by: debounceDurations.effectsDisplayUpdates)
      await store.receive(\.updateDebounced)

      var config2 = DelayConfig.Draft(
        time: store.state.config.time,
        feedback: store.state.config.feedback,
        cutoff: store.state.config.cutoff,
        wetDryMix: store.state.config.wetDryMix,
        enabled: true,
        presetId: store.state.config.presetId
      )
      config2.id = 1

      await testClock.advance(by: debounceDurations.effectsConfigurationSaves)
      await store.receive(\.saveDebounced, timeout: .seconds(1)) {
        $0.config = config2
        $0.dirty = false
      }

      await testClock.advance(by: .milliseconds(KnobConfig.default.showValueMilliseconds))

      await store.receive(\.wetDryMix.title.valueDisplayTimerFired) { $0.wetDryMix.title.formattedValue = nil }
    }

    #expect(await device.getTimesChanged() == 3)
  }

  @Test
  func globalLockEnabled() async throws {
    $delayLockEnabled.withLock { $0 = true }

    let store = store()

    await store.send(\.activePresetIdChanged, 1)
    #expect(store.state.config.enabled == false)
    #expect(store.state.locked.isOn == true)

    await store.send(.enabled(.toggleTapped(true))) {
      $0.config.enabled = false
      $0.enabled.isOn = true
      $0.dirty = false
    }

    await store.send(.enabled(.toggleTapped(false))) {
      $0.config.enabled = false
      $0.enabled.isOn = false
      $0.dirty = false
    }

    await store.send(.locked(.toggleTapped(false))) {
      $0.locked.isOn = false
    }

    await store.send(.deinitialize)

    #expect(await device.getTimesChanged() == 1)
  }

  @Test
  func presetIdChangedWhileLocked() async throws {
    $delayLockEnabled.withLock { $0 = true }

    let store = store()

    await store.send(\.activePresetIdChanged, 1)

    #expect(store.state.config.id == nil)
    #expect(store.state.locked.isOn == true)

    await store.send(\.activePresetIdChanged, 2)

    #expect(store.state.config.id == nil)
    #expect(store.state.locked.isOn == true)

    await store.send(.deinitialize)

    #expect(await device.getTimesChanged() == 1)
  }

//  @Test
//  func presetIdChangeAffectsDelayConfig() async throws {
//
//    try await initialized { store in
//
//      await store.withExhaustivity(.off) {
//        await store.send(\.activePresetIdChanged, 2)
//        await store.receive(\.applyConfigForPreset, 2)
//        await store.send(\.activePresetIdChanged, 1)
//
//        await store.receive(\.applyConfigForPreset, 2) {
//          $0.activePresetId = 2
//          $0.config =  .init(
//            id: 2,
//            time: 1.0,
//            feedback: -70,
//            cutoff: 12000.0,
//            wetDryMix: 100.0,
//            enabled: true,
//            presetId: 2
//          )
//          $0.dirty = true
//        }
//
//      }
//    }
//    #expect(await device.getTimesChanged() == 5)
//  }

  @Test
  func preview1() throws {
    withDependencies {
      $0.defaultDatabase = previewDatabase()
    } operation: {
      withSnapshotTesting(record: .failed) {
        TestSupport.assertSnapshot(matching: DelayEffectView.preview(presetId: 1), config: .landscape)
      }
    }
  }

  @Test
  func preview2() throws {
    withDependencies {
      $0.defaultDatabase = previewDatabase()
    } operation: {
      withSnapshotTesting(record: .failed) {
        TestSupport.assertSnapshot(matching: DelayEffectView.preview(presetId: 2), config: .landscape)
      }
    }
  }

  @Test
  func preview3() throws {
    withDependencies {
      $0.defaultDatabase = previewDatabase()
    } operation: {
      withSnapshotTesting(record: .failed) {
        TestSupport.assertSnapshot(matching: DelayEffectView.preview(presetId: 3), config: .landscape)
      }
    }
  }
}

private actor MockDelayDevice {
  private var config: DelayConfig.Draft = .init(presetId: -1)
  private var timesChanged: Int = 0

  func getTimesChanged() -> Int { timesChanged }

  func setConfig(_ config: DelayConfig.Draft) {
    self.config = config
    self.timesChanged += 1
  }
}

private func addDelayConfigs(_ db: Database) throws {
  try TestSupport.addMockPresets(db)
  try DelayConfig.insert {
    DelayConfig.Draft(
      time: 0.5,
      feedback: 80,
      cutoff: 8000.0,
      wetDryMix: 50.0,
      enabled: true,
      presetId: 1
    )
    DelayConfig.Draft(
      time: 1.0,
      feedback: -70,
      cutoff: 12000.0,
      wetDryMix: 100.0,
      enabled: true,
      presetId: 2
    )
    DelayConfig.Draft(
      time: 1.5,
      feedback: 80,
      cutoff: 8000.0,
      wetDryMix: 50.0,
      enabled: false,
      presetId: 3
    )
  }
  .execute(db)
}
