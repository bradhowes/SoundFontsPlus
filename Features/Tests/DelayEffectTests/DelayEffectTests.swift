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
    $0.defaultDatabase = TestSupport.testDatabase()
    $0.mainQueue = .immediate
    $0.debounceDurations = .testValue
  },
  .snapshots(record: .failed)
)
@MainActor
struct DelayEffectTests {
  fileprivate let device = MockDelayDevice()

  fileprivate func store(activePresetId: Preset.ID? = nil) -> TestStoreOf<DelayEffect> {
    TestStoreOf<DelayEffect>(initialState: .init(activePresetId: activePresetId)) {
      DelayEffect()
    } withDependencies: {
      $0.delayDevice.setConfig = { config in Task { await device.setConfig(config) } }
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
    #expect(store.state.time.value.isApproximatelyEqual(to: 0.5))
    #expect(store.state.wetDryMix.value.isApproximatelyEqual(to: 50.0))
  }

  @Test(
    .dependencies {
      $0.continuousClock = ImmediateClock()
    }
  )
  func enabledToggled() async throws {
    let store = store()
    await store.withExhaustivity(.off(showSkippedAssertions: false)) {

      await store.send(\.activePresetIdChanged, 1)

      #expect(store.state.config.id == nil)
      #expect(store.state.config.enabled == false)

      await store.send(.enabled(.toggleTapped(true))) {
        $0.config.enabled = true
        $0.enabled.isOn = true
        $0.dirty = true
      }

      await store.receive(\.updateDebounced)

      let config = DelayConfig.Draft(
        time: store.state.config.time,
        feedback: store.state.config.feedback,
        cutoff: store.state.config.cutoff,
        wetDryMix: store.state.config.wetDryMix,
        enabled: true,
        presetId: -1
      )

      await store.receive(\.saveDebounced) {
        $0.config = config
        $0.dirty = false
      }

      await store.send(.deinitialize)
    }
    #expect(await device.getTimesChanged() == 2)
  }

  @Test(
    .dependencies {
      $0.continuousClock = ImmediateClock()
    }
  )
  func wetDryMix() async throws {
    let store = store()

    await store.withExhaustivity(.off(showSkippedAssertions: false)) {
      await store.send(\.activePresetIdChanged, 1)

      #expect(store.state.config.id == nil)
      #expect(store.state.config.enabled == false)

      await store.send(.enabled(.toggleTapped(true))) {
        $0.config.enabled = true
        $0.enabled.isOn = true
        $0.dirty = true
      }

      await store.receive(\.updateDebounced)

      let config = DelayConfig.Draft(
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

      await store.withExhaustivity(.off(showSkippedAssertions: false)) {
        await store.send(.wetDryMix(.setValue(40))) {
          $0.config.wetDryMix = 40
        }

        await store.receive(\.wetDryMix)
        await store.receive(\.updateDebounced)

        let config2 = DelayConfig.Draft(
          time: store.state.config.time,
          feedback: store.state.config.feedback,
          cutoff: store.state.config.cutoff,
          wetDryMix: store.state.config.wetDryMix,
          enabled: true,
          presetId: store.state.config.presetId
        )

        await store.receive(\.saveDebounced) {
          $0.config = config2
          $0.dirty = false
        }

        await store.send(.deinitialize)
      }
      #expect(await device.getTimesChanged() == 3)
    }
  }

  @Test(
    .dependencies {
      $0.continuousClock = ImmediateClock()
      @Shared(.delayLockEnabled) var locked = true
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

  @Test(
    .dependencies { _ in
      @Shared(.delayLockEnabled) var locked = true
    }
  )
  func presetIdChangedWhileLocked() async throws {
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
      $0.defaultDatabase = TestSupport.testDatabase(seeder: addDelayConfigs)
    }
  )
  func presetIdChanged() async throws {
    let store = store()

    await store.withExhaustivity(.off(showSkippedAssertions: false)) {
      await store.send(\.activePresetIdChanged, 1)

      #expect(store.state.config.id == 1)

      await store.send(\.activePresetIdChanged, 2) {
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

      await store.send(.deinitialize)

      #expect(await device.getTimesChanged() == 3)
    }
  }

  @Test
  func preview1() throws {
    TestSupport.assertSnapshot(matching: DelayEffectView.preview(presetId: 1), config: .landscape)
  }

  @Test
  func preview2() throws {
    TestSupport.assertSnapshot(matching: DelayEffectView.preview(presetId: 2), config: .landscape)
  }

  @Test
  func preview3() throws {
    TestSupport.assertSnapshot(matching: DelayEffectView.preview(presetId: 3), config: .landscape)
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
