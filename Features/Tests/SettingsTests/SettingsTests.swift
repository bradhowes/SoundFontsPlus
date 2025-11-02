// Copyright © 2025 Brad Howes. All rights reserved.

import FeatureSupport
import MIDIConnections
import MorkAndMIDI
import SnapshotTesting
import Testing
import TestSupport

@testable import Settings

@Suite(
  .snapshots(record: .failed)
)
@MainActor
struct SettingsTests {

  @Test
  func initializeNoMidi() async throws {
    let store = TestStore(initialState: Settings.State()) { Settings() }
    await store.send(.initialize)
    await store.send(.dismissButtonTapped)
  }

  @Test
  func initializeWithMidi() async throws {
    @Shared(.midi) var midi = MIDI(clientName: "Test", uniqueId: 123, midiProto: .v1_0)
    midi?.start()
    @Shared(.midiMonitor) var midiMonitor = MIDIMonitor()
    midi?.receiver = midiMonitor

    let store = TestStore(initialState: Settings.State()) { Settings() }

    await store.send(.initialize)
    store.exhaustivity = .off
    await store.receive(\.midiConnectionCountChanged)

    // await store.skipReceivedActions(strict: false)
    midiMonitor?.noteOn(source: 123, note: 60, velocity: 64, channel: 0)
    let traffic = MIDITraffic(id: 123, channel: 0, accepted: true)
    await store.receive(\.midiTrafficIndicator.showMIDITraffic, traffic)
    await store.send(.dismissButtonTapped)
  }

  @Test
  func updateKeyWidth() async throws {
    let store = TestStore(initialState: Settings.State()) { Settings() }
    await store.send(.initialize)
    await store.send(\.binding.keyWidth, 21.2)
    @Shared(.keyWidth) var keyWidth
    #expect(keyWidth == 21.2)
    await store.send(.dismissButtonTapped)
  }

  @Test
  func copyFileWhenInstalling() async throws {
    let store = TestStore(initialState: Settings.State()) { Settings() }
    await store.send(.initialize)
    await store.send(\.binding.copyFileWhenInstalling, false) {
      $0.$copyFileWhenInstalling.withLock { $0 = true }
      $0.destination = .alert(
        AlertState.confirmDisableCopyFile(action: .disableCopyFileConfirmed)
      )
    }

    await store.send(.destination(.presented(.alert(.disableCopyFileConfirmed)))) {
      $0.$copyFileWhenInstalling.withLock { $0 = false }
      $0.destination = nil
    }

    @Shared(.copyFileWhenInstalling) var copyFileWhenInstalling
    #expect(copyFileWhenInstalling == false)
    await store.send(.dismissButtonTapped)
  }

  @Test
  func disableIdleTimer() async throws {
    let store = TestStore(initialState: Settings.State()) { Settings() }
    await store.send(.initialize)
    await store.send(\.binding.disableIdleTimer, true) {
      $0.$disableIdleTimer.withLock { $0 = false }
      $0.destination = .alert(
        AlertState.confirmDisableIdleTimer(action: .disableIdleTimerConfirmed)
      )
    }

    await store.send(.destination(.presented(.alert(.disableIdleTimerConfirmed)))) {
      $0.$disableIdleTimer.withLock { $0 = true }
      $0.destination = nil
    }

    @Shared(.disableIdleTimer) var disableIdleTimer
    #expect(disableIdleTimer == true)
    await store.send(.dismissButtonTapped)
  }

  @Test
  func midiAssignmentsButtonTapped() async throws {
    let store = TestStore(initialState: Settings.State()) { Settings() }
    await store.send(.initialize)
    _ = await store.withExhaustivity(.off(showSkippedAssertions: false)) {
      await store.send(\.midiAssignmentsButtonTapped)
    }
    #expect(store.state.path.count == 1)
    await store.send(.dismissButtonTapped)
  }

  @Test
  func midiConnectionsButtonTapped() async throws {
    let store = TestStore(initialState: Settings.State()) { Settings() }
    await store.send(.initialize)
    _ = await store.withExhaustivity(.off(showSkippedAssertions: false)) {
      await store.send(\.midiConnectionsButtonTapped)
    }
    #expect(store.state.path.count == 1)
    await store.send(.dismissButtonTapped)
  }

  @Test
  func midiControllersButtonTapped() async throws {
    let store = TestStore(initialState: Settings.State()) { Settings() }
    await store.send(.initialize)
    _ = await store.withExhaustivity(.off(showSkippedAssertions: false)) {
      await store.send(\.midiControllersButtonTapped)
    }
    #expect(store.state.path.count == 1)
    await store.send(.dismissButtonTapped)
  }

  @Test
  func viewChangesTapped() async throws {
    let store = TestStore(initialState: Settings.State()) { Settings() }
    await store.send(.initialize)
    await store.send(\.viewChangesTapped)
    await store.receive(\.delegate, .showChanges)
    await store.send(.dismissButtonTapped)
  }

  @Test
  func viewTutorialTapped() async throws {
    let store = TestStore(initialState: Settings.State()) { Settings() }
    await store.send(.initialize)
    await store.send(\.viewTutorialTapped)
    await store.receive(\.delegate, .showTutorial)
    await store.send(.dismissButtonTapped)
  }

  @Test
  func settingsViewPreview() async throws {
    let view = SettingsView.preview
    try TestSupport.assertSnapshot(matching: view)
  }
}
