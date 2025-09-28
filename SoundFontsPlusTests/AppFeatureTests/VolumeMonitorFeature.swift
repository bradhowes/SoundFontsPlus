import ComposableArchitecture
import Dependencies
import DependenciesTestSupport
import Foundation
import Sharing
import SnapshotTesting
import SwiftUI
import Testing

@testable import SoundFontsPlus

extension BaseTestSuite {

  @MainActor
  struct VolumeMonitorFeatureTests {
    private let mockVolume: VolumeMonitorDemoView.OutputVolumeFlipFlop
    private let store: TestStoreOf<VolumeMonitorFeature>

    init() async throws {
      let mockVolume = VolumeMonitorDemoView.OutputVolumeFlipFlop()
      let store = TestStore(initialState: VolumeMonitorFeature.State()) {
        VolumeMonitorFeature()
      } withDependencies: {
        @Shared(.activeState) var activeState = .init()
        $0.outputVolume = mockVolume.makeOutputVolume()
      }

      self.mockVolume = mockVolume
      self.store = store
    }
  }
}

extension BaseTestSuite.VolumeMonitorFeatureTests {

  func togglePresetId(
    assert updateStateToExpectedResult: ((_ state: inout VolumeMonitorFeature.State) throws -> Void)? = nil,
  ) async {
    @Shared(.activeState) var activeState
    let newValue = activeState.activePresetId == nil ? Preset.ID(rawValue: 1) : nil
    $activeState.activePresetId.withLock { $0 = newValue }
    await store.send(.activePresetIdChanged(newValue), assert: updateStateToExpectedResult)
  }

  @Test
  func volumeGoesToZero() async throws {
    await store.send(.initialize)
    mockVolume.advance()
    await store.receive(\.volumeChanged) { $0.noVolumeReason = .volumeLevelIsZero }
    await store.receive(\.delegate)
    mockVolume.advance()
    await store.receive(\.volumeChanged) { $0.noVolumeReason = nil }
    await store.receive(\.delegate)
    await store.send(.deinitialize)
  }

  @Test
  func activePresetBecomesNil() async throws {
    await store.send(.initialize)
    await togglePresetId { $0.noVolumeReason = .noActivePreset }
    await store.receive(\.delegate)
    await togglePresetId { $0.noVolumeReason = nil }
    await store.receive(\.delegate)
    await store.send(.deinitialize)
  }

  @Test
  func ignorePresetChangesWhenVolumeIsZero() async throws {
    await store.send(.initialize)
    mockVolume.advance()
    await store.receive(\.volumeChanged) { $0.noVolumeReason = .volumeLevelIsZero }
    await store.receive(\.delegate)
    await togglePresetId()
    await togglePresetId()
    mockVolume.advance()
    await store.receive(\.volumeChanged) { $0.noVolumeReason = nil }
    await store.receive(\.delegate)
    await store.send(.deinitialize)
  }

  @Test
  func ignoreVolumeChangesWhenPresetIsNil() async throws {
    await store.send(.initialize)
    @Shared(.activeState) var activeState
    await togglePresetId { $0.noVolumeReason = .noActivePreset }
    await store.receive(\.delegate)
    mockVolume.advance()
    await store.receive(\.volumeChanged)
    mockVolume.advance()
    await store.receive(\.volumeChanged)
    await togglePresetId { $0.noVolumeReason = nil }
    await store.receive(\.delegate)
    await store.send(.deinitialize)
  }

  @Test
  func switchReasonWhenNecessary() async throws {
    await store.send(.initialize)
    await togglePresetId { $0.noVolumeReason = .noActivePreset }
    await store.receive(\.delegate)
    mockVolume.advance()
    await store.receive(\.volumeChanged)
    await togglePresetId { $0.noVolumeReason = .volumeLevelIsZero }
    await store.receive(\.delegate)
    await togglePresetId()
    mockVolume.advance()
    await store.receive(\.volumeChanged) { $0.noVolumeReason = .noActivePreset }
    await store.receive(\.delegate)
    await store.send(.deinitialize)
  }

  @Test
  func processReason() {
    // TODO: make ProgressHUD a dependency to actually test the mapping
    VolumeMonitorModifier.processReason(.noActivePreset)
    VolumeMonitorModifier.processReason(.volumeLevelIsZero)
    VolumeMonitorModifier.processReason(nil)
  }

  @Test
  @MainActor
  func volumeMonitorPreview() async throws {
    // swiftlint:disable:next redundant_discardable_let
    let _ = prepareDependencies { $0.outputVolume = mockVolume.makeOutputVolume() }
    let store: StoreOf<VolumeMonitorFeature> = .init(
      initialState: VolumeMonitorFeature.State(
        noVolumeReason: .volumeLevelIsZero)) {
          VolumeMonitorFeature()
        }
    let view = VolumeMonitorDemoView(volumes: mockVolume, store: store)

    try withSnapshotTesting(record: .failed) {
      try BaseTestSuite.assertSnap(
        matching: view,
        size: .init(width: 400, height: 800),
        colorScheme: .dark
      )
    }
  }
}
