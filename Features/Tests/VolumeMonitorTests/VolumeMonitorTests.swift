// Copyright © 2025 Brad Howes. All rights reserved.

import DependenciesTestSupport
import FeatureSupport
import SnapshotTesting
import Testing
import TestSupport

@testable import VolumeMonitor

@Suite
@MainActor
struct VolumeMonitorTests {
  private let mockVolume: OutputVolumeFlipFlop
  private let store: TestStoreOf<VolumeMonitor>

  init() async throws {
    let mockVolume = OutputVolumeFlipFlop()
    let store = TestStore(initialState: VolumeMonitor.State()) {
      VolumeMonitor()
    } withDependencies: {
      @Shared(.activeState) var activeState = .default
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
    await store.send(.start)
    mockVolume.advance()
    await store.receive(\.volumeChanged) { $0.reason = .volumeLevelIsZero }
    await store.receive(\.delegate)
    mockVolume.advance()
    await store.receive(\.volumeChanged) { $0.reason = nil }
    await store.receive(\.delegate)
    await store.send(.stop)
  }

  @Test
  func activePresetBecomesNil() async throws {
    await store.send(.start)
    await togglePresetId { $0.reason = .noActivePreset }
    await store.receive(\.delegate)
    await togglePresetId { $0.reason = nil }
    await store.receive(\.delegate)
    await store.send(.stop)
  }

  @Test
  func ignorePresetChangesWhenVolumeIsZero() async throws {
    await store.send(.start)
    mockVolume.advance()
    await store.receive(\.volumeChanged) { $0.reason = .volumeLevelIsZero }
    await store.receive(\.delegate)
    await togglePresetId()
    await togglePresetId()
    mockVolume.advance()
    await store.receive(\.volumeChanged) { $0.reason = nil }
    await store.receive(\.delegate)
    await store.send(.stop)
  }

  @Test
  func ignoreVolumeChangesWhenPresetIsNil() async throws {
    await store.send(.start)
    @Shared(.activeState) var activeState
    await togglePresetId { $0.reason = .noActivePreset }
    await store.receive(\.delegate)
    mockVolume.advance()
    await store.receive(\.volumeChanged)
    mockVolume.advance()
    await store.receive(\.volumeChanged)
    await togglePresetId { $0.reason = nil }
    await store.receive(\.delegate)
    await store.send(.stop)
  }

  @Test
  func switchReasonWhenNecessary() async throws {
    await store.send(.start)
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
    await store.send(.stop)
  }
}
