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
      @Shared(.appActiveState) var activeState = .default
      $0.outputVolume = mockVolume.makeOutputVolume()
    }

    self.mockVolume = mockVolume
    self.store = store
  }

  func togglePresetId(
    assert updateStateToExpectedResult: ((_ state: inout VolumeMonitor.State) throws -> Void)? = nil,
  ) async {
    @Shared(.appActiveState) var activeState
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
    @Shared(.appActiveState) var activeState
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

  @Test
  func noVolumePreview() async throws {
    prepareDependencies {
      $0.outputVolume = mockVolume.makeOutputVolume()
      mockVolume.advance()
    }
    let store: StoreOf<VolumeMonitor> = .init(
      initialState: VolumeMonitor.State(reason: .volumeLevelIsZero)
    ) {
      VolumeMonitor()
    }

    let view = VolumeMonitorDemoView(volumes: mockVolume, store: store)
    #expect(mockVolume.getValue() == 0.0)

    try withSnapshotTesting(record: .failed) {
      try TestSupport.assertSnapshot(matching: view)
    }
  }

  @Test
  func noPresetPreview() async throws {
    prepareDependencies {
      $0.outputVolume = mockVolume.makeOutputVolume()
      @Shared(.appActiveState) var activeState
      $activeState.activePresetId.withLock { $0 = nil }
    }
    let store: StoreOf<VolumeMonitor> = .init(
      initialState: VolumeMonitor.State(reason: .noActivePreset)
    ) {
      VolumeMonitor()
    }

    let view = VolumeMonitorDemoView(volumes: mockVolume, store: store)

    try withSnapshotTesting(record: .failed) {
      try TestSupport.assertSnapshot(matching: view)
    }
  }
}

struct VolumeMonitorDemoView: View {

  private let volumes: OutputVolumeFlipFlop
  @State private var volume: Float
  @State private var store: StoreOf<VolumeMonitor>
  @Shared(.appActiveState) var activeState

  init(volumes: OutputVolumeFlipFlop, store: StoreOf<VolumeMonitor>) {
    self.volumes = volumes
    self.store = store
    self.volume = self.volumes.getValue()
  }

  var body: some View {
    VStack(spacing: 20) {
      Text("Volume: \(volume)")
      Text("Preset ID: \(String(describing: activeState.activePresetId))")
        .volumeMonitorHUD(store: store)
      HStack {
        Button {
          Task {
            volume = volumes.advance()
          }
        } label: {
          Text("Toggle Volume")
        }
        Button {
          Task {
            let newValue: Preset.ID? = activeState.activePresetId == nil ? Preset.ID(rawValue: 1) : nil
            store.send(.activePresetIdChanged(newValue))
            $activeState.activePresetId.withLock { $0 = newValue }
          }
        } label: {
          Text("Toggle PresetId")
        }
      }
    }
  }
}
