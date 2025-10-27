// Copyright © 2025 Brad Howes. All rights reserved.

import AVFAudio
import BaseSupport
import ComposableArchitecture
import Foundation
import DelayEffect
import Dependencies
import DependenciesTestSupport
import Models
import ReverbEffect
import Sharing
import SnapshotTesting
import SwiftUI
import Testing

@testable import Synth

@Suite(
  .dependencies {
    $0.defaultDatabase = try appDatabase()
    // TODO: use mock here
    $0.audioSession = AudioSession.liveValue
    $0.continuousClock = .immediate
  },
  .snapshots(record: .failed)
)
@MainActor
struct SynthTests {

  func initialized(_ closure: (TestStoreOf<Synth>) async throws -> Void) async throws {
    @Shared(.playSoundOnPresetChange) var playSoundOnPresetChange = false
    @Shared(.delayEffect) var delayEffect = AVAudioUnitDelay()
    @Shared(.reverbEffect) var reverbEffect = AVAudioUnitReverb()
    let store = TestStore(initialState: Synth.State()) { Synth() }

    await store.send(.initialize)

    await store.receive(\.synthAudioUnitCreated) {
      $0.audioSessionActivated = true
    }

    await store.receive(\.activePresetIdChanged, timeout: .seconds(30)) {
      $0.loadedSoundFontId = 1
      $0.loadedPresetIndex = 0
    }

    await store.receive(\.delegate, .running)

    await store.receive(\.lastPresetLoadFinished, timeout: .seconds(30)) {
      $0.firstTimePresetLoaded = false
    }

    try await closure(store)

    await store.send(.deinitialize)
    await store.finish(timeout: .seconds(1))
  }

  @Test func initialize() async throws {
    guard !ProcessInfo.processInfo.isOnGithub else { return }
    try await initialized { _ in }
  }

  @Test func activePresetIdChanged() async throws {
    guard !ProcessInfo.processInfo.isOnGithub else { return }
    try await initialized { store in
      @Shared(.activeState) var activeState
      $activeState.withLock { $0.activePresetId = .init(rawValue: 5) }
      try await $activeState.load()

      await store.receive(\.activePresetIdChanged, timeout: .seconds(30)) {
        $0.loadedPresetIndex = 4
      }

      await store.receive(\.lastPresetLoadFinished, timeout: .seconds(30))
    }
  }

  @Test func activePresetIdChangeCanPlayNote() async throws {
    guard !ProcessInfo.processInfo.isOnGithub else { return }
    try await initialized { store in

      @Shared(.playSoundOnPresetChange) var playSoundOnPresetChange
      $playSoundOnPresetChange.withLock { $0 = true }

      @Shared(.activeState) var activeState
      $activeState.withLock { $0.activePresetId = .init(rawValue: 5) }
      try await $activeState.load()

      await store.receive(\.activePresetIdChanged, timeout: .seconds(30)) {
        $0.loadedPresetIndex = 4
      }

      await store.receive(\.lastPresetLoadFinished, timeout: .seconds(30))
    }
  }

  @Test func audioSessionRouteChanged() async throws {
    guard !ProcessInfo.processInfo.isOnGithub else { return }
    try await initialized { store in
      NotificationCenter.default.post(name: AVAudioSession.routeChangeNotification, object: nil)
      await store.receive(\.audioSessionRouteChanged)
    }
  }

  @Test func audioSessionMediaServicesWereReset() async throws {
    guard !ProcessInfo.processInfo.isOnGithub else { return }
    try await initialized { store in
      NotificationCenter.default.post(name: AVAudioSession.mediaServicesWereResetNotification, object: nil)
      await store.receive(\.mediaServicesWereReset)
    }
  }

  @Test func audioSessionReleaseAcquire() async throws {
    guard !ProcessInfo.processInfo.isOnGithub else { return }
    try await initialized { store in
      await store.send(\.releaseAudioSession)
      await store.send(\.acquireAudioSession)

      @Shared(.backgroundProcessing) var backgroundProcessing
      $backgroundProcessing.withLock { $0 = false }

      await store.send(\.releaseAudioSession) {
        $0.audioSessionActivated = false
      }

      await store.send(\.acquireAudioSession) {
        $0.audioSessionActivated = true
      }
    }
  }
}

