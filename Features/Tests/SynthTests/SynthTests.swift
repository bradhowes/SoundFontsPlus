// Copyright © 2025 Brad Howes. All rights reserved.

import AVFAudio
import BaseSupport
import ComposableArchitecture
import DelayEffect
import DependenciesTestSupport
import Foundation
import Models
import ReverbEffect
import SF2LibAU
import SnapshotTesting
import SwiftUI
import Testing
import TestSupport

@testable import Synth

@Suite(
  .dependencies {
    $0.audioGraph = .liveValue
    $0.audioSession = .liveValue
    $0.avAudioUnitMIDIInstrumentGenerator = await AVAudioUnitMIDIInstrumentGenerator.constant()
    $0.continuousClock = TestClock<Duration>()
    $0.date = .constant(.now)
    $0.defaultDatabase = TestSupport.testDatabase()
    $0.delayDevice = .liveValue
    $0.fileManager = .liveValue
    $0.reverbDevice = .liveValue
    $0.uuid = .incrementing
  },
  .snapshots(record: .failed),
  .serialized // due to SF2LibAU creation
)
@MainActor
struct SynthTests {
  @Shared(.playSoundOnPresetChange) var playSoundOnPresetChange = false
  @Shared(.backgroundProcessing) var backgroundProcessing = false

  func initialized(exhaustivity: Exhaustivity = .on, _ closure: (TestStoreOf<Synth>) async throws -> Void) async throws {
    guard !ProcessInfo.processInfo.isOnGithub else { return }

    @Dependency(\.avAudioUnitMIDIInstrumentGenerator) var avAudioUnitMIDIInstrumentGenerator
    let avAudioUnit = await avAudioUnitMIDIInstrumentGenerator.generate()

    let store = TestStore(initialState: Synth.State()) { Synth() }

    try await store.withExhaustivity(exhaustivity) {
      await store.send(.initialize)

      await store.receive(\.synthAudioUnitCreated) {
        $0.audioSessionActivated = true
        $0.avAudioUnit = avAudioUnit
      }

      await store.receive(\.delegate.running)
      await store.receive(\.delegate.audioUnitCreated)

      try await closure(store)

      await store.send(.deinitialize)
    }
  }

  @Test
  func initialize() async throws {
    try await initialized { _ in }
  }

  @Test
  func activePresetIdChanged() async throws {
    try await initialized { store in

      await store.send(\.activePresetIdChanged, 2) {
        $0.loadedSoundFontId = 1
        $0.loadedPresetIndex = 1
        $0.activePresetId = 2
      }

      await store.receive(\.lastPresetLoadFinished, timeout: .seconds(5))
    }
  }

  @Test
  func activePresetIdChangeCanPlayNote() async throws {
    try await initialized { store in
      $playSoundOnPresetChange.withLock { $0 = true }

      await store.send(\.activePresetIdChanged, 2) {
        $0.loadedSoundFontId = 1
        $0.loadedPresetIndex = 1
        $0.activePresetId = 2
      }

      await store.receive(\.lastPresetLoadFinished, timeout: .seconds(5))

      await store.send(\.activePresetIdChanged, 1) {
        $0.loadedSoundFontId = 1
        $0.loadedPresetIndex = 0
        $0.activePresetId = 1
      }

      await store.receive(\.lastPresetLoadFinished, timeout: .seconds(5))
    }
  }

  @Test
  func audioSessionRouteChanged() async throws {
    try await initialized { store in
      NotificationCenter.default.post(name: AVAudioSession.routeChangeNotification, object: nil)
      await store.receive(\.audioSessionRouteChanged)
    }
  }

  @Test
  func audioSessionMediaServicesWereReset() async throws {
    try await initialized { store in
      NotificationCenter.default.post(name: AVAudioSession.mediaServicesWereResetNotification, object: nil)
      await store.receive(\.mediaServicesWereReset)
    }
  }

  @Test
  func audioSessionReleaseAcquire() async throws {
    try await initialized { store in
      await store.send(\.releaseAudioSession) { $0.audioSessionActivated = false }
      await store.send(\.acquireAudioSession) { $0.audioSessionActivated = true }
      await store.send(\.releaseAudioSession) { $0.audioSessionActivated = false }
      await store.send(\.acquireAudioSession) { $0.audioSessionActivated = true }
    }
  }
}
