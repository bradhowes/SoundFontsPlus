import AUv3Controls
import AVFAudio.AVAudioUnitDelay
import ComposableArchitecture
import DependenciesTestSupport
import Foundation
import Models
import Numerics
import Sharing
import SnapshotTesting
import SwiftUI
import Testing

@testable import DelayEffect

@Suite(.dependencies { $0.defaultDatabase = try appDatabase() })
@MainActor
struct DelayEffectTests {
  fileprivate let device = DelayDevice()
  @Shared(.parameterTree) var parameterTree
  @Shared(.delayLockEnabled) var locked = false
  @Shared(.activeState) var activeState

  init() {
    $activeState.activePresetId.withLock { $0 = 1 }
  }

  fileprivate func store() -> TestStoreOf<DelayEffect> {
    TestStoreOf<DelayEffect>(initialState: .init()) {
      DelayEffect()
    } withDependencies: {
      $0.delayDevice = .init(setConfig: { config in Task { await device.setConfig(config) } })
      $0.mainQueue = .immediate
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
}

private actor DelayDevice {
  private var config: DelayConfig.Draft = .init(presetId: -1)
  private var timesChanged: Int = 0

  func getTimesChanged() -> Int { timesChanged }

  func setConfig(_ config: DelayConfig.Draft) {
    self.config = config
    self.timesChanged += 1
  }
}

extension DelayEffectTests {

  @Test func setConfig() throws {
    let delay = AVAudioUnitDelay()
    let delayConfig: DelayConfig.Draft = .init(
      time: 0.1,
      feedback: 0.2,
      cutoff: 345.6,
      wetDryMix: 0.7,
      enabled: true,
      presetId: 1
    )
    delay.setConfig(delayConfig)
    #expect(delay.delayTime.isApproximatelyEqual(to: 0.1))
    #expect(delay.feedback.isApproximatelyEqual(to: 0.2))
    #expect(delay.lowPassCutoff.isApproximatelyEqual(to: 345.6))
    #expect(delay.wetDryMix.isApproximatelyEqual(to: 0.7))
    #expect(!delay.bypass)
  }
}
