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
    $0.defaultDatabase = try appDatabase()
    $0.mainQueue = .immediate
  },
  .snapshots(record: .failed)
)
@MainActor
struct ReverbEffectTests {
  fileprivate let device = ReverbDevice()
  @Shared(.parameterTree) var parameterTree
  @Shared(.activeState) var activeState = .default

  fileprivate func store() -> TestStoreOf<ReverbEffect> {
    TestStoreOf<ReverbEffect>(initialState: .init()) {
      ReverbEffect()
    } withDependencies: {
      $0.reverbDevice = .init(setConfig: { config in Task { await device.setConfig(config) } })
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

    await store.receive(\.wetDryMix)

    store.exhaustivity = .on
    await store.send(.deinitialize)

    #expect(await device.getTimesChanged() == 1)
  }

  @Test func roomPresetChanged() async throws {
    let store = store()

    store.exhaustivity = .off(showSkippedAssertions: false)
    await store.send(.initialize)
    await store.receive(\.activePresetIdChanged)

    await store.receive(\.applyConfigForPreset) {
      $0.config.presetId = 1
    }

    #expect(store.state.config.id == nil)

    await store.receive(\.wetDryMix)

    #expect(store.state.config.id == nil)

    store.exhaustivity = .on
    await store.send(.roomPresetChanged(.plate)) {
      $0.config.roomPreset = .plate
      $0.dirty = true
    }

    await store.receive(\.updateDebounced, timeout: 30)

    let config = ReverbConfig.Draft(
      id: 1,
      roomPreset: store.state.config.roomPreset,
      wetDryMix: store.state.config.wetDryMix,
      enabled: store.state.config.enabled,
      presetId: store.state.config.presetId
    )

    await store.receive(\.saveDebounced, timeout: 30) {
      $0.config = config
      $0.dirty = false
    }

    await store.send(.deinitialize)

    #expect(await device.getTimesChanged() == 2)
  }

  @Test func enabledToggled() async throws {
    let store = store()

    store.exhaustivity = .off(showSkippedAssertions: false)
    await store.send(.initialize)
    await store.receive(\.activePresetIdChanged)

    await store.receive(\.applyConfigForPreset) {
      $0.config.presetId = 1
    }

    #expect(store.state.config.id == nil)
    #expect(store.state.config.enabled == false)

    await store.receive(\.wetDryMix)

    store.exhaustivity = .on
    await store.send(.enabled(.toggleTapped(true))) {
      $0.config.enabled = true
      $0.enabled.isOn = true
      $0.dirty = true
    }

    await store.receive(\.updateDebounced)

    let config = ReverbConfig.Draft(
      id: 1,
      roomPreset: store.state.config.roomPreset,
      wetDryMix: store.state.config.wetDryMix,
      enabled: store.state.config.enabled,
      presetId: store.state.config.presetId
    )

    await store.receive(\.saveDebounced) {
      $0.config = config
      $0.dirty = false
    }

    await store.send(.deinitialize)

    #expect(await device.getTimesChanged() == 2)
  }

  @Test func wetDryMix() async throws {
    let store = store()

    store.exhaustivity = .off(showSkippedAssertions: false)
    await store.send(.initialize)
    await store.receive(\.activePresetIdChanged)

    await store.receive(\.applyConfigForPreset) {
      $0.config.presetId = 1
    }

    #expect(store.state.config.id == nil)
    #expect(store.state.config.enabled == false)

    await store.receive(\.wetDryMix)

    await store.send(.enabled(.toggleTapped(true))) {
      $0.config.enabled = true
      $0.enabled.isOn = true
      $0.dirty = true
    }

    await store.receive(\.updateDebounced)

    let config = ReverbConfig.Draft(
      id: 1,
      roomPreset: store.state.config.roomPreset,
      wetDryMix: store.state.config.wetDryMix,
      enabled: store.state.config.enabled,
      presetId: store.state.config.presetId
    )

    await store.receive(\.saveDebounced) {
      $0.config = config
      $0.dirty = false
    }

    store.exhaustivity = .off(showSkippedAssertions: false)
    await store.send(.wetDryMix(.setValue(50))) {
      $0.config.wetDryMix = 50.0
    }

    await store.receive(\.wetDryMix) // (.control(.title(.valueDisplayTimerFired))))

    store.exhaustivity = .on

    await store.receive(\.updateDebounced)

    let config2 = ReverbConfig.Draft(
      id: 1,
      roomPreset: store.state.config.roomPreset,
      wetDryMix: store.state.config.wetDryMix,
      enabled: store.state.config.enabled,
      presetId: store.state.config.presetId
    )

    await store.receive(\.saveDebounced) {
      $0.config = config2
      $0.dirty = false
    }

    await store.send(.deinitialize)

    #expect(await device.getTimesChanged() == 3)
  }

  @Test func globalLockDisabled() async throws {
    @Shared(.reverbLockEnabled) var locked = true
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

    let config1 = ReverbConfig.Draft(
      id: nil,
      roomPreset: store.state.config.roomPreset,
      wetDryMix: store.state.config.wetDryMix,
      enabled: store.state.config.enabled,
      presetId: -1
    )

    await store.receive(\.updateDebounced)

    await store.receive(\.saveDebounced) {
      $0.config = config1
      $0.dirty = false
    }

    let config2 = ReverbConfig.Draft(
      id: 1,
      roomPreset: store.state.config.roomPreset,
      wetDryMix: store.state.config.wetDryMix,
      enabled: store.state.config.enabled,
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
    @Shared(.reverbLockEnabled) var locked = true
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
      $0.defaultDatabase = try appDatabase(seeder: addReverbConfigs)
    },
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

    await store.receive(\.wetDryMix)

    store.exhaustivity = .on
    @Shared(.activeState) var activeState
    $activeState.withLock { $0.activePresetId = .init(rawValue: 2) }

    await store.receive(\.activePresetIdChanged, 2)

    store.exhaustivity = .off(showSkippedAssertions: false)
    await store.receive(\.applyConfigForPreset, 2) {
      $0.config =  .init(
        id: 2,
        roomPreset: .cathedral,
        wetDryMix: 81.0,
        enabled: true,
        presetId: 2
      )
    }

    await store.receive(\.wetDryMix)

    await store.send(.deinitialize)

    #expect(await device.getTimesChanged() == 2)
  }

  @Test func preview() throws {
    try TestSupport.assertSnapshot(matching: ReverbEffectView.preview)
  }
}

private actor ReverbDevice {
  private var config: ReverbConfig.Draft = .init(presetId: -1)
  private var timesChanged: Int = 0

  func getTimesChanged() -> Int { timesChanged }

  func setConfig(_ config: ReverbConfig.Draft) {
    self.config = config
    self.timesChanged += 1
  }
}

private func addReverbConfigs(_ db: Database) throws {
  try ReverbConfig.insert {
    ReverbConfig.Draft(
      roomPreset: .plate,
      wetDryMix: 50.0,
      enabled: true,
      presetId: 1
    )
  }
  .execute(db)
  try ReverbConfig.insert {
    ReverbConfig.Draft(
      roomPreset: .cathedral,
      wetDryMix: 81.0,
      enabled: true,
      presetId: 2
    )
  }
  .execute(db)
  try ReverbConfig.insert {
    ReverbConfig.Draft(
      roomPreset: .smallRoom,
      wetDryMix: 20.0,
      enabled: false,
      presetId: 3
    )
  }
  .execute(db)
}
