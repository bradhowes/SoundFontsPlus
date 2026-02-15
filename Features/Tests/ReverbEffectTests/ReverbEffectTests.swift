// Copyright © 2025 Brad Howes. All rights reserved.

import AUv3Controls
import DependenciesTestSupport
import FeatureSupport
import Numerics
import SnapshotTesting
import SQLiteData
import Testing
import TestSupport

@testable import ReverbEffect

@Suite(
  .dependencies {
    $0.defaultDatabase = TestSupport.testDatabase()
    $0.mainQueue = .immediate
    $0.continuousClock = .immediate
    $0.debounceDurations = .testValue
  },
  .snapshots(record: .failed)
)
@MainActor
struct ReverbEffectTests {
  fileprivate let device = MockReverbDevice()

  fileprivate func store(activePresetId: Preset.ID? = nil) -> TestStoreOf<ReverbEffect> {
    TestStoreOf<ReverbEffect>(initialState: .init(activePresetId: activePresetId)) {
      ReverbEffect()
    } withDependencies: {
      $0.reverbDevice.setConfig = { config in Task { await device.setConfig(config) } }
    }
  }

  @Test
  func initialization() async throws {
    let store = store()
    await store.withExhaustivity(.off(showSkippedAssertions: false)) {
      await store.send(\.activePresetIdChanged, 1) {
        $0.activePresetId = 1
        $0.config.presetId = -1
      }
      await store.send(.deinitialize)
    }
    #expect(await device.getTimesChanged() == 1)
    #expect(store.state.wetDryMix.value.isApproximatelyEqual(to: 50.0))
  }

  @Test
  func roomPresetChanged() async throws {
    @Dependency(\.mainQueue) var mainQueue
    @Dependency(\.debounceDurations) var debounceDurations

    let store = store()

    await store.withExhaustivity(.off(showSkippedAssertions: false)) {

      await store.send(\.activePresetIdChanged, 1)

      #expect(store.state.config.id == nil)
      #expect(store.state.config.enabled == false)
    }

    await store.send(.roomPresetChanged(.plate)) {
      $0.config.roomPreset = .plate
      $0.config.presetId = store.state.activePresetId!
      $0.dirty = true
    }

    try? await mainQueue.sleep(for: debounceDurations.effectsDisplayUpdates)
    await store.receive(\.updateDebounced)

    let config = ReverbConfig.Draft(
      id: 1,
      roomPreset: store.state.config.roomPreset,
      wetDryMix: store.state.config.wetDryMix,
      enabled: store.state.config.enabled,
      presetId: store.state.config.presetId
    )

    try? await mainQueue.sleep(for: debounceDurations.effectsConfigurationSaves)
    await store.receive(\.saveDebounced) {
      $0.config = config
      $0.dirty = false
    }

    await store.send(.deinitialize)

    #expect(await device.getTimesChanged() == 2)
  }

  @Test
  func enabledToggled() async throws {
    @Dependency(\.mainQueue) var mainQueue
    @Dependency(\.debounceDurations) var debounceDurations

    let store = store()

    await store.withExhaustivity(.off(showSkippedAssertions: false)) {
      await store.send(\.activePresetIdChanged, 1)

      #expect(store.state.config.id == nil)
      #expect(store.state.config.enabled == false)
    }

    await store.send(.enabled(.toggleTapped(true))) {
      $0.config.presetId = store.state.activePresetId!
      $0.config.enabled = true
      $0.enabled.isOn = true
      $0.dirty = true
    }

    try? await mainQueue.sleep(for: debounceDurations.effectsDisplayUpdates)
    await store.receive(\.updateDebounced)

    let config = ReverbConfig.Draft(
      id: 1,
      roomPreset: store.state.config.roomPreset,
      wetDryMix: store.state.config.wetDryMix,
      enabled: store.state.config.enabled,
      presetId: store.state.config.presetId
    )

    try? await mainQueue.sleep(for: debounceDurations.effectsConfigurationSaves)
    await store.receive(\.saveDebounced) {
      $0.config = config
      $0.dirty = false
    }

    await store.send(.deinitialize)

    #expect(await device.getTimesChanged() == 2)
  }

  @Test
  func wetDryMix() async throws {
    @Dependency(\.mainQueue) var mainQueue
    @Dependency(\.debounceDurations) var debounceDurations

    let store = store()

    await store.withExhaustivity(.off(showSkippedAssertions: false)) {
      await store.send(\.activePresetIdChanged, 1)

      #expect(store.state.config.id == nil)
      #expect(store.state.config.enabled == false)
    }

    await store.send(.enabled(.toggleTapped(true))) {
      $0.config.presetId = store.state.activePresetId!
      $0.config.enabled = true
      $0.enabled.isOn = true
      $0.dirty = true
    }

    try? await mainQueue.sleep(for: debounceDurations.effectsDisplayUpdates)
    await store.receive(\.updateDebounced)

    let config = ReverbConfig.Draft(
      id: 1,
      roomPreset: store.state.config.roomPreset,
      wetDryMix: store.state.config.wetDryMix,
      enabled: store.state.config.enabled,
      presetId: store.state.config.presetId
    )

    try? await mainQueue.sleep(for: debounceDurations.effectsConfigurationSaves)
    await store.receive(\.saveDebounced) {
      $0.config = config
      $0.dirty = false
    }

    await store.withExhaustivity(.off(showSkippedAssertions: false)) {
      await store.send(.wetDryMix(.setValue(40))) {
        $0.config.wetDryMix = 40.0
      }

      await store.receive(\.wetDryMix)

      try? await mainQueue.sleep(for: debounceDurations.effectsDisplayUpdates)
      await store.receive(\.updateDebounced)

      let config2 = ReverbConfig.Draft(
        id: 1,
        roomPreset: store.state.config.roomPreset,
        wetDryMix: store.state.config.wetDryMix,
        enabled: store.state.config.enabled,
        presetId: store.state.config.presetId
      )

      try? await mainQueue.sleep(for: debounceDurations.effectsConfigurationSaves)
      await store.receive(\.saveDebounced) {
        $0.config = config2
        $0.dirty = false
      }
    }

    await store.send(.deinitialize)

    #expect(await device.getTimesChanged() == 3)
  }

  @Test(
    .dependencies { _ in
      @Shared(.reverbLockEnabled) var locked = true
    }
  )
  func globalLockEnabled() async throws {
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
    @Shared(.reverbLockEnabled) var locked = true
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

  @Test(
    .dependencies {
      $0.defaultDatabase = TestSupport.testDatabase(seeder: addReverbConfigs)
    },
  )
  func presetIdChanged() async throws {
    let store = store()

    await store.withExhaustivity(.off(showSkippedAssertions: false)) {
      await store.send(\.activePresetIdChanged, 1)

      #expect(store.state.config.id == 1)

      await store.send(\.activePresetIdChanged, 2) {
        $0.config =  .init(
          id: 2,
          roomPreset: .cathedral,
          wetDryMix: 81.0,
          enabled: true,
          presetId: 2
        )
      }

      await store.send(.deinitialize)

      #expect(await device.getTimesChanged() == 3)
    }
  }

  @Test
  func preview() throws {
    TestSupport.assertSnapshot(matching: ReverbEffectView.preview)
  }
}

private actor MockReverbDevice {
  private var config: ReverbConfig.Draft = .init(presetId: -1)
  private var timesChanged: Int = 0

  func getTimesChanged() -> Int { timesChanged }

  func setConfig(_ config: ReverbConfig.Draft) {
    self.config = config
    self.timesChanged += 1
  }
}

private func addReverbConfigs(_ db: Database) throws {
  try TestSupport.addMockPresets(db)
  try ReverbConfig.insert {
    ReverbConfig.Draft(
      roomPreset: .plate,
      wetDryMix: 50.0,
      enabled: true,
      presetId: 1
    )
    ReverbConfig.Draft(
      roomPreset: .cathedral,
      wetDryMix: 81.0,
      enabled: true,
      presetId: 2
    )
    ReverbConfig.Draft(
      roomPreset: .smallRoom,
      wetDryMix: 20.0,
      enabled: false,
      presetId: 3
    )
  }
  .execute(db)
}
