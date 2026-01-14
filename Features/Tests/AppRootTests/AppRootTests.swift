// Copyright © 2025 Brad Howes. All rights reserved.

import AVFAudio
import DelayEffect
import DependenciesTestSupport
import FeatureSupport
import Models
import ReverbEffect
import Settings
import Sharing
import SnapshotTesting
import SoundFonts
import Testing
import TestSupport
import Tutorial

@testable import Presets
@testable import AppRoot

@Suite(
  .dependencies {
    let mockVolume = OutputVolumeFlipFlop()
    $0.audioGraph = .previewValue
    $0.audioSession = .liveValue
    $0.avAudioUnitMIDIInstrumentGenerator = await AVAudioUnitMIDIInstrumentGenerator.constant()
    $0.delayDevice = .liveValue
    $0.date = .constant(.now)
    $0.defaultDatabase = TestSupport.testDatabase()
    $0.mainQueue = .immediate
    $0.outputVolume = mockVolume.makeOutputVolume()
    $0.reverbDevice = .liveValue
  },
  .snapshots(record: .failed)
)
@MainActor
struct AppRootTests {

  func store(showedTutorial: Bool = true) -> TestStoreOf<AppRoot> {
    @Shared(.activeState) var activeState = .default
    @Shared(.showedTutorial) var showedTutorial = showedTutorial
    return .init(initialState: .init()) {
      AppRoot()
    }
  }

  func initialized(
    exhaustivity: Exhaustivity = .on,
    showedTutorial: Bool = true,
    _ closure: (TestStoreOf<AppRoot>) async throws -> Void
  ) async throws {
    guard !ProcessInfo.processInfo.isOnGithub else { return }

    @Dependency(\.avAudioUnitMIDIInstrumentGenerator) var avAudioUnitMIDIInstrumentGenerator
    let avAudioUnit = try #require(await avAudioUnitMIDIInstrumentGenerator.generate())

    let store = store(showedTutorial: showedTutorial)

    try await store.withExhaustivity(exhaustivity) {
      await store.send(.initialize)
      await store.receive(\.activePresetIdChanged)
      await store.receive(\.synth.synthAudioUnitCreated) {
        $0.synth.audioSessionActivated = true
        $0.synth.avAudioUnit = avAudioUnit
      }
      await store.receive(\.synth.delegate.audioUnitCreated) {
        $0.keyboard.midiInstrument = $0.synth.avAudioUnit
      }
      await store.receive(\.synth.delegate.running) {
        $0.synth.loadedSoundFontId = 1
        $0.synth.loadedPresetIndex = 0
        $0.toolBar.preset = Preset.with(id: 1)
        $0.toastState = nil
      }

      try await closure(store)

      await store.send(.deinitialize)
      await store.finish()
    }
  }

  @Test
  func initialize() async throws {
    try await initialized { _ in }
  }

  @Test
  func disableIdleTimer() throws {
    @Shared(.disableIdleTimer) var disableIdleTimer = false
    #expect(!UIKit.UIApplication.shared.isIdleTimerDisabled)

    AppRoot.disableIdleTimer()
    #expect(!UIKit.UIApplication.shared.isIdleTimerDisabled)

    $disableIdleTimer.withLock { $0 = true }
    AppRoot.disableIdleTimer()
    // NOTE: does not appear to work in test environment
    // #expect(UIKit.UIApplication.shared.isIdleTimerDisabled)
  }

  @Test
  func processPresetsSplitAction() async throws {
    try await initialized { store in
      @Shared(.fontsAndPresetsSplitPosition) var fontsAndPresetsSplitPosition
      #expect(fontsAndPresetsSplitPosition == 0.5)
      await store.send(\.fontsAndPresetsSplit.delegate, .stateChanged(panesVisible: .both, position: 0.3))
      #expect(fontsAndPresetsSplitPosition == 0.3)
    }
  }

  @Test
  func processTagsSplitAction() async throws {
    try await initialized { store in
      @Shared(.tagsListVisible) var tagsListVisible
      @Shared(.fontsAndTagsSplitPosition) var fontsAndTagsSplitPosition
      #expect(tagsListVisible == false)
      #expect(fontsAndTagsSplitPosition == 0.4)
      await store.send(\.fontsAndTagsSplit.delegate, .stateChanged(panesVisible: .both, position: 0.5)) {
        $0.toolBar.tagsListVisible.toggle()
      }
      #expect(tagsListVisible == true)
      #expect(fontsAndTagsSplitPosition == 0.5)
    }
  }

  @Test
  func refreshPresets() async throws {
    try await initialized { store in
      let soundFont = SoundFont.with(id: 1)!
      await store.send(\.soundFontsList.delegate, .edit(soundFont)) {
        $0.destination = .soundFontEditor(SoundFontEditor.State(soundFont: soundFont))
      }
      _ = await store.withExhaustivity(.off(showSkippedAssertions: false)) {
        await store.send(\.destination.presented.soundFontEditor.delegate, .refreshPresets)
      }
    }
  }

  @Test
  func showChanges() async throws {
    try await initialized(exhaustivity: .off(showSkippedAssertions: false)) { store in
      @Shared(.lastShowedChangesVersion) var lastShowedChangesVersion
      await store.send(\.toolBar.delegate, .settingsButtonTapped)
      #expect(store.state.destination != nil)
      let settings = store.state.destination
      #expect(lastShowedChangesVersion == "")
      await store.send(\.destination.settings.delegate, .showChanges)
      #expect(store.state.destination != settings)
      #expect(lastShowedChangesVersion != "")
    }
  }

  @Test
  func showSoundFontEditor() async throws {
    try await initialized { store in
      let soundFont = SoundFont.with(id: 1)!
      await store.send(\.soundFontsList.delegate, .edit(soundFont)) {
        $0.destination = .soundFontEditor(SoundFontEditor.State(soundFont: soundFont))
      }
    }
  }

  @Test
  func showTagsEditor() async throws {
    try await initialized { store in
      _ = await store.withExhaustivity(.off(showSkippedAssertions: false)) {
        await store.send(\.tagsList.delegate, .edit(1))
        #expect(store.state.destination != nil)
      }
    }
  }

  @Test
  func showTutorial() async throws {
    @Shared(.showedTutorial) var showedTutorial
    try await initialized(exhaustivity: .off(showSkippedAssertions: false)) { store in
      await store.send(\.toolBar.delegate, .settingsButtonTapped)
      #expect(store.state.destination != nil)
      let settings = store.state.destination
      $showedTutorial.withLock { $0 = false }
      await store.send(\.destination.settings.delegate, .showTutorial)
      #expect(store.state.destination != settings)
      #expect(showedTutorial == true)
    }
  }

  @Test
  func appRootViewPreview() async throws {
    try TestSupport.assertSnapshot(matching: AppRootView.preview)
  }

  @Test
  func appRootViewLoadingPreview() async throws {
    try TestSupport.assertSnapshot(matching: AppRootView.preview)
  }
}
