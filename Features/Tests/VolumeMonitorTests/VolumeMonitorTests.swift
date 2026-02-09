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
      $0.outputVolume = mockVolume.makeOutputVolume()
    }

    self.mockVolume = mockVolume
    self.store = store
  }

  func togglePresetId(
    _ activePresetId: inout Preset.ID?,
    assert updateStateToExpectedResult: ((_ state: inout VolumeMonitor.State) throws -> Void)? = nil,
  ) async {
    let newValue = activePresetId == nil ? Preset.ID(rawValue: 1) : nil
    activePresetId = newValue
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
    var activePresetId: Preset.ID? = Preset.ID(rawValue: 1)
    await store.send(.start)
    await togglePresetId(&activePresetId) { $0.reason = .noActivePreset }
    await store.receive(\.delegate)
    await togglePresetId(&activePresetId) { $0.reason = nil }
    await store.receive(\.delegate)
    await store.send(.stop)
  }

  @Test
  func ignorePresetChangesWhenVolumeIsZero() async throws {
    var activePresetId: Preset.ID? = Preset.ID(rawValue: 1)
    await store.send(.start)
    mockVolume.advance()
    await store.receive(\.volumeChanged) { $0.reason = .volumeLevelIsZero }
    await store.receive(\.delegate)
    await togglePresetId(&activePresetId)
    await togglePresetId(&activePresetId)
    mockVolume.advance()
    await store.receive(\.volumeChanged) { $0.reason = nil }
    await store.receive(\.delegate)
    await store.send(.stop)
  }

  @Test
  func ignoreVolumeChangesWhenPresetIsNil() async throws {
    var activePresetId: Preset.ID? = Preset.ID(rawValue: 1)
    await store.send(.start)
    await togglePresetId(&activePresetId) { $0.reason = .noActivePreset }
    await store.receive(\.delegate)
    mockVolume.advance()
    await store.receive(\.volumeChanged)
    mockVolume.advance()
    await store.receive(\.volumeChanged)
    await togglePresetId(&activePresetId) { $0.reason = nil }
    await store.receive(\.delegate)
    await store.send(.stop)
  }

  @Test
  func switchReasonWhenNecessary() async throws {
    var activePresetId: Preset.ID? = Preset.ID(rawValue: 1)
    await store.send(.start)
    await togglePresetId(&activePresetId) { $0.reason = .noActivePreset }
    await store.receive(\.delegate)
    mockVolume.advance()
    await store.receive(\.volumeChanged)
    await togglePresetId(&activePresetId) { $0.reason = .volumeLevelIsZero }
    await store.receive(\.delegate)
    await togglePresetId(&activePresetId)
    mockVolume.advance()
    await store.receive(\.volumeChanged) { $0.reason = .noActivePreset }
    await store.receive(\.delegate)
    await store.send(.stop)
  }
}
