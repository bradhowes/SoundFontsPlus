import AUv3Controls
import ComposableArchitecture
import Foundation
import Sharing
import SnapshotTesting
import SwiftUI
import Testing

@testable import SoundFontsPlus

extension BaseTestSuite {

  @MainActor
  struct ReverbEffectTests {
    fileprivate let device = ReverbDevice()

    @Test func initialization() async throws {
      @Shared(.parameterTree) var parameterTree
      @Shared(.reverbLockEnabled) var locked = false
      @Shared(.activeState) var activeState
      $activeState.activePresetId.withLock { $0 = 1 }

      let store = TestStoreOf<ReverbFeature>(initialState: .init()) {
        ReverbFeature()
      } withDependencies: {
        $0.reverbDevice = .init(setConfig: { device.config = $0 })
        $0.mainQueue = .immediate
      }

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
}

private class ReverbDevice {
  var config: ReverbConfig.Draft = .init(presetId: -1) {
    didSet { timesChanged += 1 }
  }
  var timesChanged: Int = 0
}
