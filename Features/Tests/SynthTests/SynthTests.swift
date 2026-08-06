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
import SF2Resources
import SnapshotTesting
import SQLiteData
import SwiftUI
import Tagged
import Testing
import TestSupport

@testable import Synth

@Suite(
  .dependencies {
    $0.audioGraph = .liveValue
    $0.audioSession = .liveValue
    $0.avAudioUnitMIDIInstrumentGenerator = .liveValue
    $0.continuousClock = TestClock<Duration>()
    $0.date = .constant(.now)
    $0.defaultDatabase = try appDatabase(fonts: [SF2ResourceTag.fluidFont], loadAllPresets: false)
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

    let store = TestStore(initialState: Synth.State()) { Synth() }

    try await store.withExhaustivity(exhaustivity) {
      await store.send(.initialize)

      await store.withExhaustivity(.off(showSkippedAssertions: false)) {
        await store.receive(\.synthAudioUnitCreated) {
          $0.audioSessionActivated = true
        }
        #expect(store.state.avAudioUnit != nil)
      }

      await store.receive(\.delegate.running, store.state.avAudioUnit!)

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

      await store.receive(\.lastPresetLoadFinished, timeout: .seconds(5)) {
        $0.firstTimeLoading = false
      }
    }
  }

  @Test(
    .dependencies {
      $0.avAudioUnitMIDIInstrumentGenerator = .liveValue
    }
  )
  func activePresetIdChangeCanPlayNote() async throws {
    try await initialized { store in
      $playSoundOnPresetChange.withLock { $0 = true }

      await store.send(\.activePresetIdChanged, 2) {
        $0.loadedSoundFontId = 1
        $0.loadedPresetIndex = 1
        $0.activePresetId = 2
      }

      await store.receive(\.lastPresetLoadFinished, timeout: .seconds(5)) {
        $0.firstTimeLoading = false
      }

      await store.send(\.activePresetIdChanged, 1) {
        $0.loadedSoundFontId = 1
        $0.loadedPresetIndex = 0
        $0.activePresetId = 1
      }

      await store.receive(\.lastPresetLoadFinished, timeout: .seconds(5))
    }
  }

  @Test(
    .dependencies {
      $0.avAudioUnitMIDIInstrumentGenerator = .liveValue
    }
  )
  func audioSessionRouteChanged() async throws {
    try await initialized { store in
      NotificationCenter.default.post(name: AVAudioSession.routeChangeNotification, object: nil)
      await store.receive(\.audioSessionRouteChanged)
    }
  }

  @Test(
    .dependencies {
      $0.avAudioUnitMIDIInstrumentGenerator = .liveValue
    }
  )
  func audioSessionMediaServicesWereReset() async throws {
    try await initialized { store in
      NotificationCenter.default.post(name: AVAudioSession.mediaServicesWereResetNotification, object: nil)
      await store.receive(\.mediaServicesWereReset)
    }
  }

  @Test(
    .dependencies {
      $0.avAudioUnitMIDIInstrumentGenerator = .liveValue
    }
  )
  func audioSessionReleaseAcquire() async throws {
    try await initialized { store in
      await store.send(\.releaseAudioSession) { $0.audioSessionActivated = false }
      await store.send(\.acquireAudioSession) { $0.audioSessionActivated = true }
      await store.send(\.releaseAudioSession) { $0.audioSessionActivated = false }
      await store.send(\.acquireAudioSession) { $0.audioSessionActivated = true }
    }
  }
}
