import AUv3Controls
import ComposableArchitecture
import Foundation
import Numerics
import Sharing
import SnapshotTesting
import SwiftUI
import Testing

@testable import SoundFontsPlus

extension BaseTestSuite {

  @MainActor
  struct DelayEffectTests {
    fileprivate let device = DelayDevice()
    @Shared(.parameterTree) var parameterTree
    @Shared(.delayLockEnabled) var locked = false
    @Shared(.activeState) var activeState

    init() {
      $activeState.activePresetId.withLock { $0 = 1 }
    }

    fileprivate func store() -> TestStoreOf<DelayFeature> {
      TestStoreOf<DelayFeature>(initialState: .init()) {
        DelayFeature()
      } withDependencies: {
        $0.delayDevice = .init(setConfig: { device.config = $0 })
        $0.mainQueue = .immediate
      }
    }
  }
}

extension BaseTestSuite.DelayEffectTests {

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

    #expect(device.timesChanged == 1)
    #expect(store.state.time.value.isApproximatelyEqual(to: 0.5))
  }
}

private class DelayDevice {
  var config: DelayConfig.Draft = .init(presetId: -1) {
    didSet { timesChanged += 1 }
  }
  var timesChanged: Int = 0
}
