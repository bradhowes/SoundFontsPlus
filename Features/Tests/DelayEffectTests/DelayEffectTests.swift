// Copyright © 2025 Brad Howes. All rights reserved.

import AUv3Controls
import DependenciesTestSupport
import FeatureSupport
import SnapshotTesting
import SQLiteData
import Testing
import TestSupport

@testable import DelayEffect

@Suite(
  .dependencies {
    $0.defaultDatabase = TestSupport.testDatabase()
    $0.mainQueue = .immediate
    $0.debounceDurations = .testValue
  },
  .snapshots(record: .failed)
)
@MainActor
struct DelayEffectTests {
  fileprivate let device = MockDelayDevice()
  @Shared(.activeState) var activeState = .default

  fileprivate func store() -> TestStoreOf<DelayEffect> {
    TestStoreOf<DelayEffect>(initialState: .init()) {
      DelayEffect()
    } withDependencies: {
      $0.delayDevice = .init(setConfig: { config in Task { await device.setConfig(config) } })
    }
  }

  @Test func initialization() async throws {
    let store = store()

    store.exhaustivity = .off(showSkippedAssertions: false)
    await store.send(.initialize)
    await store.receive(\.activePresetIdChanged)

    await store.receive(\.applyConfigForPreset) {
      $0.config.presetId = 1
    }

    await store.receive(\.time)
    await store.receive(\.feedback)
    await store.receive(\.cutoff)
    await store.receive(\.wetDryMix)

    await store.send(.deinitialize)

    #expect(await device.getTimesChanged() == 1)
    #expect(store.state.time.value.isApproximatelyEqual(to: 0.5))
  }

  @Test func enabledToggled() async throws {
    let store = store()
    await store.withExhaustivity(.off(showSkippedAssertions: false)) {
      await store.send(.initialize)
      await store.receive(\.activePresetIdChanged)

      await store.receive(\.applyConfigForPreset) {
        $0.config.presetId = 1
      }

      #expect(store.state.config.id == nil)
      #expect(store.state.config.enabled == false)

      await store.receive(\.time)
      await store.receive(\.feedback)
      await store.receive(\.cutoff)
      await store.receive(\.wetDryMix)

      await store.send(.enabled(.toggleTapped(true))) {
        $0.config.enabled = true
        $0.enabled.isOn = true
        $0.dirty = true
      }

      await store.receive(\.updateDebounced, timeout: 90)

      let config = DelayConfig.Draft(
        id: 1,
        time: store.state.config.time,
        feedback: store.state.config.feedback,
        cutoff: store.state.config.cutoff,
        wetDryMix: store.state.config.wetDryMix,
        enabled: true,
        presetId: 1
      )

      await store.receive(\.saveDebounced, timeout: 90) {
        $0.config = config
        $0.dirty = false
      }

      await store.send(.deinitialize)
    }
    #expect(await device.getTimesChanged() == 2)
  }

  @Test func wetDryMix() async throws {
    let store = store()
    await store.withExhaustivity(.off(showSkippedAssertions: false)) {
      await store.send(.initialize)
      await store.receive(\.activePresetIdChanged)

      await store.receive(\.applyConfigForPreset) {
        $0.config.presetId = 1
      }

      #expect(store.state.config.id == nil)
      #expect(store.state.config.enabled == false)

      await store.receive(\.time)
      await store.receive(\.feedback)
      await store.receive(\.cutoff)
      await store.receive(\.wetDryMix)

      await store.send(.enabled(.toggleTapped(true))) {
        $0.config.enabled = true
        $0.enabled.isOn = true
        $0.dirty = true
      }

      await store.receive(\.updateDebounced)

      let config = DelayConfig.Draft(
        id: 1,
        time: store.state.config.time,
        feedback: store.state.config.feedback,
        cutoff: store.state.config.cutoff,
        wetDryMix: store.state.config.wetDryMix,
        enabled: true,
        presetId: store.state.config.presetId
      )

      await store.receive(\.saveDebounced) {
        $0.config = config
        $0.dirty = false
      }

      store.exhaustivity = .off(showSkippedAssertions: false)
      await store.send(.wetDryMix(.setValue(100))) {
        $0.config.wetDryMix = 100
      }

      await store.receive(\.wetDryMix, timeout: 90)
      await store.receive(\.updateDebounced, timeout: 90)

      let config2 = DelayConfig.Draft(
        id: 1,
        time: store.state.config.time,
        feedback: store.state.config.feedback,
        cutoff: store.state.config.cutoff,
        wetDryMix: store.state.config.wetDryMix,
        enabled: true,
        presetId: store.state.config.presetId
      )

      await store.receive(\.saveDebounced, timeout: 90) {
        $0.config = config2
        $0.dirty = false
      }

      await store.send(.deinitialize)
    }
    #expect(await device.getTimesChanged() == 3)
  }

  @Test func globalLockDisabled() async throws {
    @Shared(.delayLockEnabled) var locked = true
    let store = store()

    store.exhaustivity = .off(showSkippedAssertions: false)
    await store.send(.initialize)
    await store.receive(\.activePresetIdChanged)

    #expect(store.state.config.enabled == false)
    #expect(store.state.locked.isOn == true)

    store.exhaustivity = .on
    await store.send(.enabled(.toggleTapped(true))) {
      $0.config.enabled = true
      $0.enabled.isOn = true
      $0.dirty = true
    }

    store.exhaustivity = .on

    let config1 = DelayConfig.Draft(
      id: nil,
      time: store.state.config.time,
      feedback: store.state.config.feedback,
      cutoff: store.state.config.cutoff,
      wetDryMix: store.state.config.wetDryMix,
      enabled: true,
      presetId: store.state.config.presetId
    )


    await store.receive(\.updateDebounced)

    await store.receive(\.saveDebounced) {
      $0.config = config1
      $0.dirty = false
    }

    let config2 = DelayConfig.Draft(
      id: 1,
      time: store.state.config.time,
      feedback: store.state.config.feedback,
      cutoff: store.state.config.cutoff,
      wetDryMix: store.state.config.wetDryMix,
      enabled: true,
      presetId: 1
    )

    await store.send(.locked(.toggleTapped(false))) {
      $0.config.enabled = true
      $0.enabled.isOn = true
      $0.locked.isOn = false
      $0.config = config2
      $0.dirty = false
    }

    await store.send(.deinitialize)

    #expect(await device.getTimesChanged() == 2)
  }

  @Test func presetIdChangedWhileLocked() async throws {
    @Shared(.delayLockEnabled) var locked = true
    let store = store()

    await store.send(.initialize)
    await store.receive(\.activePresetIdChanged)

    #expect(store.state.config.id == nil)
    #expect(store.state.locked.isOn == true)

    @Shared(.activeState) var activeState
    $activeState.withLock { $0.activePresetId = 2 }

    await store.receive(\.activePresetIdChanged, 2)

    await store.send(.deinitialize)

    #expect(await device.getTimesChanged() == 0)
  }

  @Test(
    .dependencies {
      $0.defaultDatabase = TestSupport.testDatabase(seeder: addDelayConfigs)
    }
  )
  func presetIdChanged() async throws {
    let store = store()

    store.exhaustivity = .off(showSkippedAssertions: false)
    await store.send(.initialize)
    await store.receive(\.activePresetIdChanged, 1)

    await store.receive(\.applyConfigForPreset, 1) {
      $0.config.presetId = 1
    }

    #expect(store.state.config.id == 1)

    await store.receive(\.time)
    await store.receive(\.feedback)
    await store.receive(\.cutoff)
    await store.receive(\.wetDryMix)

    store.exhaustivity = .on
    @Shared(.activeState) var activeState
    $activeState.withLock { $0.activePresetId = 2 }

    await store.receive(\.activePresetIdChanged, 2)

    store.exhaustivity = .off(showSkippedAssertions: false)
    await store.receive(\.applyConfigForPreset, 2) {
      $0.config =  .init(
        id: 2,
        time: 1.0,
        feedback: -70,
        cutoff: 12000.0,
        wetDryMix: 100.0,
        enabled: true,
        presetId: 2
      )
    }

    // Disabled due to flaky tests
//    await store.receive(\.time, timeout: 30)
//    await store.receive(\.feedback, timeout: 30)
//    await store.receive(\.cutoff, timeout: 30)
//    await store.receive(\.wetDryMix, timeout: 30)

    await store.send(.deinitialize)

    #expect(await device.getTimesChanged() == 2)
  }

  @Test func preview1() throws {
    let device = MockDelayDevice()
    try withDependencies {
      $0.delayDevice = .init(setConfig: { config in Task { await device.setConfig(config) } })
    } operation: {
      try TestSupport.assertSnapshot(matching: DelayEffectView.preview(presetId: 1), config: .landscape)
    }
  }

  @Test func preview2() throws {
    let device = MockDelayDevice()
    try withDependencies {
      $0.delayDevice = .init(setConfig: { config in Task { await device.setConfig(config) } })
    } operation: {
      try TestSupport.assertSnapshot(matching: DelayEffectView.preview(presetId: 2), config: .landscape)
    }
  }
  
  @Test func preview3() throws {
    let device = MockDelayDevice()
    try withDependencies {
      $0.delayDevice = .init(setConfig: { config in Task { await device.setConfig(config) } })
    } operation: {
      try TestSupport.assertSnapshot(matching: DelayEffectView.preview(presetId: 3), config: .landscape)
    }
  }
}

fileprivate actor MockDelayDevice {
  private var config: DelayConfig.Draft = .init(presetId: -1)
  private var timesChanged: Int = 0

  func getTimesChanged() -> Int { timesChanged }

  func setConfig(_ config: DelayConfig.Draft) {
    self.config = config
    self.timesChanged += 1
  }
}

fileprivate func addDelayConfigs(_ db: Database) throws {
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
