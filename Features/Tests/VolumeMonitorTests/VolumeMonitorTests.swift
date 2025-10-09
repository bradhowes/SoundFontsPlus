import ComposableArchitecture
import CustomSnapshot
import Dependencies
import DependenciesTestSupport
import Foundation
import Models
import Sharing
import SnapshotTesting
import SwiftUI
import Testing

@testable import VolumeMonitor

@Suite(
  .dependencies {
    $0.defaultDatabase = try appDatabase()
  },
  //  .snapshots(record: .failed)
)
@MainActor
struct VolumeMonitorTests {
  private let mockVolume: VolumeMonitorDemoView.OutputVolumeFlipFlop
  private let store: TestStoreOf<VolumeMonitor>

  init() async throws {
    let mockVolume = VolumeMonitorDemoView.OutputVolumeFlipFlop()
    let store = TestStore(initialState: VolumeMonitor.State()) {
      VolumeMonitor()
    } withDependencies: {
      @Shared(.activeState) var activeState = .init()
      $0.outputVolume = mockVolume.makeOutputVolume()
    }

    self.mockVolume = mockVolume
    self.store = store
  }

  func togglePresetId(
    assert updateStateToExpectedResult: ((_ state: inout VolumeMonitor.State) throws -> Void)? = nil,
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
    await store.receive(\.volumeChanged) { $0.reason = .volumeLevelIsZero }
    await store.receive(\.delegate)
    mockVolume.advance()
    await store.receive(\.volumeChanged) { $0.reason = nil }
    await store.receive(\.delegate)
    await store.send(.deinitialize)
  }

  @Test
  func activePresetBecomesNil() async throws {
    await store.send(.initialize)
    await togglePresetId { $0.reason = .noActivePreset }
    await store.receive(\.delegate)
    await togglePresetId { $0.reason = nil }
    await store.receive(\.delegate)
    await store.send(.deinitialize)
  }

  @Test
  func ignorePresetChangesWhenVolumeIsZero() async throws {
    await store.send(.initialize)
    mockVolume.advance()
    await store.receive(\.volumeChanged) { $0.reason = .volumeLevelIsZero }
    await store.receive(\.delegate)
    await togglePresetId()
    await togglePresetId()
    mockVolume.advance()
    await store.receive(\.volumeChanged) { $0.reason = nil }
    await store.receive(\.delegate)
    await store.send(.deinitialize)
  }

  @Test
  func ignoreVolumeChangesWhenPresetIsNil() async throws {
    await store.send(.initialize)
    @Shared(.activeState) var activeState
    await togglePresetId { $0.reason = .noActivePreset }
    await store.receive(\.delegate)
    mockVolume.advance()
    await store.receive(\.volumeChanged)
    mockVolume.advance()
    await store.receive(\.volumeChanged)
    await togglePresetId { $0.reason = nil }
    await store.receive(\.delegate)
    await store.send(.deinitialize)
  }

  @Test
  func switchReasonWhenNecessary() async throws {
    await store.send(.initialize)
    await togglePresetId { $0.reason = .noActivePreset }
    await store.receive(\.delegate)
    mockVolume.advance()
    await store.receive(\.volumeChanged)
    await togglePresetId { $0.reason = .volumeLevelIsZero }
    await store.receive(\.delegate)
    await togglePresetId()
    mockVolume.advance()
    await store.receive(\.volumeChanged) { $0.reason = .noActivePreset }
    await store.receive(\.delegate)
    await store.send(.deinitialize)
  }

  @Test
  func noVolumePreview() async throws {
    // swiftlint:disable:next redundant_discardable_let
    let _ = prepareDependencies {
      $0.outputVolume = mockVolume.makeOutputVolume()
      mockVolume.advance()
    }
    let store: StoreOf<VolumeMonitor> = .init(
      initialState: VolumeMonitor.State(
        reason: .volumeLevelIsZero)) {
          VolumeMonitor()
        }

    let view = VolumeMonitorDemoView(volumes: mockVolume, store: store)
    #expect(mockVolume.getValue() == 0.0)

    try withSnapshotTesting(record: .failed) {
      try CustomSnapshot.assertSnapshot(matching: view)
    }
  }

  @Test
  func noPresetPreview() async throws {
    // swiftlint:disable:next redundant_discardable_let
    let _ = prepareDependencies {
      $0.outputVolume = mockVolume.makeOutputVolume()
      @Shared(.activeState) var activeState
      $activeState.activePresetId.withLock { $0 = nil }
    }
    let store: StoreOf<VolumeMonitor> = .init(
      initialState: VolumeMonitor.State(
        reason: .noActivePreset )
    ) {
      VolumeMonitor()
    }

    let view = VolumeMonitorDemoView(volumes: mockVolume, store: store)

    try withSnapshotTesting(record: .failed) {
      try CustomSnapshot.assertSnapshot(matching: view)
    }
  }
}
