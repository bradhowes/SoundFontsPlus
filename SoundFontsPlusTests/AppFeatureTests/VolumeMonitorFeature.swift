import ComposableArchitecture
import Dependencies
import DependenciesTestSupport
import Foundation
import Sharing
import SnapshotTesting
import SwiftUI
import Testing

@testable import SoundFontsPlus

extension BaseSuite {

  @Suite
  struct VolumeMonitorFeatureTests {
    private let volumes: OutputVolumeFlipFlop
    private let store: TestStoreOf<VolumeMonitorFeature>

    init() async throws {
      let volumes = OutputVolumeFlipFlop()
      let store = await TestStore(initialState: VolumeMonitorFeature.State()) {
        VolumeMonitorFeature()
      } withDependencies: {
        @Shared(.activeState) var activeState = .init()
        $0.outputVolume = volumes.outputVolume()
      }

      self.volumes = volumes
      self.store = store
    }

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
      volumes.advance()
      await store.receive(\.volumeChanged) { $0.noVolumeReason = .volumeLevelIsZero }
      await store.receive(\.delegate)
      volumes.advance()
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
      volumes.advance()
      await store.receive(\.volumeChanged) { $0.noVolumeReason = .volumeLevelIsZero }
      await store.receive(\.delegate)
      await togglePresetId()
      await togglePresetId()
      volumes.advance()
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
      volumes.advance()
      await store.receive(\.volumeChanged)
      volumes.advance()
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
      volumes.advance()
      await store.receive(\.volumeChanged)
      await togglePresetId { $0.noVolumeReason = .volumeLevelIsZero }
      await store.receive(\.delegate)
      await togglePresetId()
      volumes.advance()
      await store.receive(\.volumeChanged) { $0.noVolumeReason = .noActivePreset }
      await store.receive(\.delegate)
      await store.send(.deinitialize)
    }

    @Test
    @MainActor
    func volumeMonitorPreview() async throws {
      let volumes = OutputVolumeFlipFlop()
      // swiftlint:disable:next redundant_discardable_let
      let _ = prepareDependencies { $0.outputVolume = volumes.outputVolume() }
      let store: StoreOf<VolumeMonitorFeature> = .init(
        initialState: VolumeMonitorFeature.State(
          noVolumeReason: .volumeLevelIsZero)) {
        VolumeMonitorFeature()
      }
      let view = VolumeMonitorDemoView(volumes: volumes, store: store)

      guard isLocal else { return }

      withSnapshotTesting(record: .failed) {
        assertSnapshot(
          of: view,
          as: .image(
            drawHierarchyInKeyWindow: true,
            layout: .fixed(width: 400, height: 800),
            traits: .init(userInterfaceStyle: .dark)
          )
        )
      }
    }
  }
}
