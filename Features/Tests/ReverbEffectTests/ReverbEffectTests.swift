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
    $0.defaultDatabase = TestSupport.testDatabase(seeder: addReverbConfigs)
    $0.mainQueue = .immediate
    $0.continuousClock = .immediate
    $0.debounceDurations = .testValue
    $0.uuid = .incrementing
  },
  .snapshots(record: .failed)
)
@MainActor
struct ReverbEffectTests {
  fileprivate let device = MockReverbDevice()

  fileprivate func store() -> TestStoreOf<ReverbEffect> {
    TestStoreOf<ReverbEffect>(initialState: .init(activePresetId: nil)) {
      ReverbEffect()
    } withDependencies: {
      $0.reverbDevice = .init(effect: nil, setConfig: { _, config in Task { await device.setConfig(config) } })
    }
  }

  func initialized(_ closure: (_ store: TestStoreOf<ReverbEffect>) async throws -> Void) async throws {
    let store = store()
    await store.send(\.activePresetIdChanged, 1) {
      $0.activePresetId = 1
      $0.config = ReverbConfig.Draft(ReverbConfig.with(presetId: 1)!)
    }

    await store.receive(\.enabled.setValue, true) {
      $0.enabled.isOn = true
    }
    await store.receive(\.wetDryMix.setValueSilently, 50.0)
    await store.receive(\.wetDryMix.track.valueChanged, 50.0)

    try await closure(store)

    await store.send(.deinitialize)
  }

  @Test
  func initialization() async throws {
    try await initialized { store in
      #expect(store.state.wetDryMix.value.isApproximatelyEqual(to: 50.0))
    }
    #expect(await device.getTimesChanged() == 2)
  }

  @Test
  func roomPresetChanged() async throws {
    @Dependency(\.continuousClock) var clock
    @Dependency(\.debounceDurations) var debounceDurations

    try await initialized { store in
      #expect(store.state.config.id == 1)
      #expect(store.state.config.enabled == true)

      await store.send(.roomPresetChanged(.cathedral)) {
        $0.config.roomPreset = .cathedral
        $0.config.presetId = store.state.activePresetId!
        $0.dirty = true
      }

      try await clock.sleep(for: debounceDurations.effectsDisplayUpdates)
      await store.receive(\.updateDebounced)

      let config = ReverbConfig.Draft(
        id: 1,
        roomPreset: store.state.config.roomPreset,
        wetDryMix: store.state.config.wetDryMix,
        enabled: store.state.config.enabled,
        presetId: store.state.config.presetId
      )

      try? await clock.sleep(for: debounceDurations.effectsConfigurationSaves)
      await store.receive(\.saveDebounced) {
        $0.config = config
        $0.dirty = false
      }
    }

    #expect(await device.getTimesChanged() == 3)
  }

  @Test
  func enabledToggled() async throws {
    @Dependency(\.continuousClock) var clock
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

      try await clock.sleep(for: debounceDurations.effectsDisplayUpdates)
      await store.receive(\.updateDebounced)

      let config = ReverbConfig.Draft(
        id: 1,
        roomPreset: store.state.config.roomPreset,
        wetDryMix: store.state.config.wetDryMix,
        enabled: store.state.config.enabled,
        presetId: store.state.config.presetId
      )

      try? await clock.sleep(for: debounceDurations.effectsConfigurationSaves)
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
    @Dependency(\.debounceDurations) var debounceDurations

    try await initialized { store in

      await store.send(.wetDryMix(.setValue(40)))
      await store.receive(\.wetDryMix) { $0.wetDryMix.title.formattedValue = "40" }
      await store.receive(\.wetDryMix.track.valueChanged, 40.0) {
        $0.config.wetDryMix = 40.0
        $0.wetDryMix.track.norm = 0.4
        $0.dirty = true
      }

      try await clock.sleep(for: debounceDurations.effectsDisplayUpdates)
      await store.receive(\.updateDebounced)

      let config2 = ReverbConfig.Draft(
        id: 1,
        roomPreset: store.state.config.roomPreset,
        wetDryMix: store.state.config.wetDryMix,
        enabled: store.state.config.enabled,
        presetId: store.state.config.presetId
      )

      try await clock.sleep(for: debounceDurations.effectsConfigurationSaves)
      await store.receive(\.saveDebounced) {
        $0.config = config2
        $0.dirty = false
      }

      await store.receive(\.wetDryMix.title.valueDisplayTimerFired) { $0.wetDryMix.title.formattedValue = nil }
    }

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

  @Test
  func presetIdChanged() async throws {
    @Dependency(\.continuousClock) var clock
    @Dependency(\.debounceDurations) var debounceDurations

    try await initialized { store in

      #expect(store.state.config.id == 1)

      await store.send(\.activePresetIdChanged, 2) {
        $0.activePresetId = .init(2)
        $0.config =  .init(
          id: 2,
          roomPreset: .cathedral,
          wetDryMix: 81.0,
          enabled: true,
          presetId: 2
        )
      }

      await store.receive(\.enabled.setValue, true)
      await store.receive(\.wetDryMix.setValue, 81.0) {
        $0.config.wetDryMix = 50.0
        $0.dirty = true
      }
      await store.receive(\.wetDryMix.title.valueChanged, 81.0) {
        $0.wetDryMix.title.formattedValue = "81"
      }
      await store.receive(\.wetDryMix.track.valueChanged, 81.0) {
        $0.config.wetDryMix = 81.0
        $0.wetDryMix.track.norm = 0.81
        $0.wetDryMix.title.formattedValue = "81"
      }

      try await clock.sleep(for: debounceDurations.effectsDisplayUpdates)
      await store.receive(\.updateDebounced)

      try await clock.sleep(for: debounceDurations.effectsConfigurationSaves)
      await store.receive(\.saveDebounced) {
        $0.dirty = false
      }

      await store.receive(\.wetDryMix.title.valueDisplayTimerFired) { $0.wetDryMix.title.formattedValue = nil }

    }
    #expect(await device.getTimesChanged() == 4)
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
