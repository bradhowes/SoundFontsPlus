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

  @Suite
  struct ReverbEffectTests {
    fileprivate let device = ReverbDevice()
    @Shared(.parameterTree) var parameterTree
    @Shared(.delayLockEnabled) var locked = false
    @Shared(.activeState) var activeState

    init() {
      $activeState.activePresetId.withLock { $0 = 1 }
    }

    fileprivate func store() -> TestStoreOf<ReverbFeature> {
      TestStoreOf<ReverbFeature>(initialState: .init()) {
        ReverbFeature()
      } withDependencies: {
        $0.reverbDevice = .init(setConfig: { device.config = $0 })
        $0.mainQueue = .immediate
      }
    }
  }
}

extension BaseTestSuite.ReverbEffectTests {

  @MainActor
  @Test func initialization() async throws {
    let store = store()

    store.exhaustivity = .off(showSkippedAssertions: false)
    await store.send(.initialize)
    await store.receive(\.activePresetIdChanged)

    await store.receive(\.applyConfigForPreset) {
      $0.config.presetId = 1
    }

    await store.receive(\.wetDryMix)

    await store.send(.deinitialize)

    #expect(device.timesChanged == 1)
  }
}

private class ReverbDevice {
  var config: ReverbConfig.Draft = .init(presetId: -1) {
    didSet { timesChanged += 1 }
  }
  var timesChanged: Int = 0
}
