// Copyright © 2025 Brad Howes. All rights reserved.

import DependenciesTestSupport
import FeatureSupport
import MIDIConnections
import MorkAndMIDI
import SnapshotTesting
import Testing
import TestSupport

@testable import Settings

@Suite(
  .dependencies {
    $0.defaultDatabase = TestSupport.testDatabase()
  },
  .snapshots(record: .failed)
)
@MainActor
struct SettingsTests {

  func initialized(_ closure: (_ store: TestStoreOf<Settings>) async throws -> Void) async throws {
    let store = TestStore(initialState: Settings.State()) { Settings() }
    await store.send(.initialize)
    await store.receive(\.midiTrafficIndicator.initialize)
    try await closure(store)
  }

  @Test
  func initializeNoMidi() async throws {
    try await initialized { store in
      await store.send(.dismissButtonTapped)
    }
  }

  @Test
  func initializeWithMidi() async throws {
    @Shared(.midi) var midi = MIDI(clientName: "Test", uniqueId: 123, midiProto: .v1_0)
    midi?.start()
    @Shared(.midiMonitor) var midiMonitor = MIDIMonitor(instrument: MockAudioUnit())
    midi?.receiver = midiMonitor

    try await initialized { store in
      await store.withExhaustivity(.off(showSkippedAssertions: false)) {
        await store.receive(\.midiConnectionsChanged)
        midiMonitor?.noteOn(source: 123, note: 60, velocity: 64, channel: 0)
        let traffic = MIDITrafficStat(id: 123, channel: 0, accepted: true)
        await store.receive(\.midiTrafficIndicator.showMIDITraffic, traffic)
        await store.send(.dismissButtonTapped)
      }
    }
  }

  @Test
  func updateKeyWidth() async throws {
    try await initialized { store in
      await store.send(\.binding.keyWidth, 21.2) {
        $0.keyWidth = 21.2
      }
      @Shared(.keyWidth) var keyWidth
      #expect(keyWidth == 21.2)
      await store.send(.dismissButtonTapped)
    }
  }

  @Test
  func copyFileWhenInstalling() async throws {
    try await initialized { store in
      await store.send(\.binding.copyFileWhenInstalling, false) {
        $0.copyFileWhenInstalling = true
        $0.destination = .alert(
          AlertState.confirmDisableCopyFile(action: .disableCopyFileConfirmed)
        )
      }

      await store.send(.destination(.presented(.alert(.disableCopyFileConfirmed)))) {
        $0.copyFileWhenInstalling = false
        $0.destination = nil
      }

      @Shared(.copyFileWhenInstalling) var copyFileWhenInstalling
      #expect(copyFileWhenInstalling == false)
      await store.send(.dismissButtonTapped)
    }
  }

  @Test
  func disableIdleTimer() async throws {
    try await initialized { store in
      await store.send(\.binding.disableIdleTimer, true) {
        $0.disableIdleTimer = false
        $0.destination = .alert(
          AlertState.confirmDisableIdleTimer(action: .disableIdleTimerConfirmed)
        )
      }

      await store.send(.destination(.presented(.alert(.disableIdleTimerConfirmed)))) {
        $0.disableIdleTimer = true
        $0.destination = nil
      }

      @Shared(.disableIdleTimer) var disableIdleTimer
      #expect(disableIdleTimer == true)
      await store.send(.dismissButtonTapped)
    }
  }

  @Test
  func midiAssignmentsButtonTapped() async throws {
    try await initialized { store in
      _ = await store.withExhaustivity(.off(showSkippedAssertions: false)) {
        await store.send(\.midiAssignmentsButtonTapped)
      }
      #expect(store.state.path.count == 1)
      await store.send(.dismissButtonTapped)
    }
  }

  @Test
  func midiConnectionsButtonTapped() async throws {
    try await initialized { store in
      _ = await store.withExhaustivity(.off(showSkippedAssertions: false)) {
        await store.send(\.midiConnectionsButtonTapped)
      }
      #expect(store.state.path.count == 1)
      await store.send(.dismissButtonTapped)
    }
  }

  @Test
  func midiControllersButtonTapped() async throws {
    try await initialized { store in
      _ = await store.withExhaustivity(.off(showSkippedAssertions: false)) {
        await store.send(\.midiControllersButtonTapped)
      }
      #expect(store.state.path.count == 1)
      await store.send(.dismissButtonTapped)
    }
  }

  @Test
  func viewChangesTapped() async throws {
    try await initialized { store in
      await store.send(.delegate(.showChanges))
      await store.send(.dismissButtonTapped)
    }
  }

  @Test
  func viewTutorialTapped() async throws {
    try await initialized { store in
      await store.send(.delegate(.showTutorial))
      await store.send(.dismissButtonTapped)
    }
  }

  @Test
  func settingsViewPreview() async throws {
    withDependencies {
      $0.defaultDatabase = previewDatabase()
      $0.fileManager.cloudDocumentsDirectory = { nil }
    } operation: {
      withSnapshotTesting(record: .failed) {
        TestSupport.assertSnapshot(matching: SettingsView.preview)
      }
    }
  }
}
