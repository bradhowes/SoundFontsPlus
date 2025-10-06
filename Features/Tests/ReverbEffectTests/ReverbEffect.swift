import AUv3Controls
import ComposableArchitecture
import DependenciesTestSupport
import Foundation
import Models
import Numerics
import Sharing
import SnapshotTesting
import SwiftUI
import Testing

@testable import ReverbEffect

@Suite(
  .dependencies {
    $0.defaultDatabase = try appDatabase()
  },
  //  .snapshots(record: .failed)
)
@MainActor
struct ReverbEffectTests {
  fileprivate let device = ReverbDevice()
  @Shared(.parameterTree) var parameterTree
  @Shared(.delayLockEnabled) var locked = false
  @Shared(.activeState) var activeState

  init() {
    $activeState.activePresetId.withLock { $0 = 1 }
  }

  fileprivate func store() -> TestStoreOf<ReverbEffect> {
    TestStoreOf<ReverbEffect>(initialState: .init()) {
      ReverbEffect()
    } withDependencies: {
      $0.reverbDevice = .init(setConfig: { config in Task { await device.setConfig(config) } })
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

    await store.receive(\.wetDryMix)

    await store.send(.deinitialize)

    #expect(await device.getTimesChanged() == 1)
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
