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
  },
  .snapshots(record: .failed)
)
@MainActor
struct SynthTests {

  @Test
  func initialize() async throws {
    guard !ProcessInfo.processInfo.isOnGithub else { return }

    @Shared(.delayEffect) var delayEffect = AVAudioUnitDelay()
    @Shared(.reverbEffect) var reverbEffect = AVAudioUnitReverb()
    let store = TestStore(initialState: Synth.State()) { Synth() }

    await store.send(.initialize)

    await store.receive(\.synthCreated) {
      $0.loadedSoundFontId = 1
      $0.loadedPresetIndex = 0
      $0.sessionActive = true
    }

    await store.receive(\.activePresetIdChanged, timeout: .seconds(30))
    await store.receive(\.lastPresetLoadFinished) {
      $0.firstTimePresetLoaded = false
    }
    await store.send(.deinitialize)
    await store.finish(timeout: .seconds(1))
  }

  @Test
  func activePresetIdChanged() async throws {
    guard !ProcessInfo.processInfo.isOnGithub else { return }

    @Shared(.delayEffect) var delayEffect = AVAudioUnitDelay()
    @Shared(.reverbEffect) var reverbEffect = AVAudioUnitReverb()
    let store = TestStore(initialState: Synth.State()) { Synth() }

    await store.send(.initialize)

    await store.receive(\.synthCreated) {
      $0.loadedSoundFontId = 1
      $0.loadedPresetIndex = 0
      $0.sessionActive = true
    }

    await store.receive(\.activePresetIdChanged, timeout: .seconds(30))
    await store.receive(\.lastPresetLoadFinished, timeout: .seconds(30)) {
      $0.firstTimePresetLoaded = false
    }

    @Shared(.activeState) var activeState
    $activeState.withLock { $0.activePresetId = .init(rawValue: 5) }
    try await $activeState.load()

    await store.receive(\.activePresetIdChanged, timeout: .seconds(30)) {
      $0.loadedPresetIndex = 4
    }

    await store.receive(\.lastPresetLoadFinished, timeout: .seconds(30))

    await store.send(.deinitialize)
    await store.finish(timeout: .seconds(1))
  }

  @Test
  func audioSessionRouteChanged() async throws {
    guard !ProcessInfo.processInfo.isOnGithub else { return }

    @Shared(.delayEffect) var delayEffect = AVAudioUnitDelay()
    @Shared(.reverbEffect) var reverbEffect = AVAudioUnitReverb()
    let store = TestStore(initialState: Synth.State()) { Synth() }

    await store.send(.initialize)

    await store.receive(\.synthCreated) {
      $0.loadedSoundFontId = 1
      $0.loadedPresetIndex = 0
      $0.sessionActive = true
    }

    await store.receive(\.activePresetIdChanged, timeout: .seconds(30))
    await store.receive(\.lastPresetLoadFinished, timeout: .seconds(30)) {
      $0.firstTimePresetLoaded = false
    }

    await store.send(.audioSessionRouteChanged)

    await store.send(.deinitialize)
    await store.finish(timeout: .seconds(1))
  }
}

