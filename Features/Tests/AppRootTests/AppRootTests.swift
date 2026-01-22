// Copyright © 2025 Brad Howes. All rights reserved.

import AVFAudio
import DelayEffect
import DependenciesTestSupport
import FeatureSupport
import Models
import ReverbEffect
import Settings
import SF2LibAU
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
    @Shared(.activeState) var activeState
    $activeState.withLock {
      $0 = .init(
        activeSoundFontId: 1,
        activePresetId: 1,
        activeTagId: -1,
        activeDelayConfigId: nil,
        activeReverbConfigId: nil
      )
    }
    $0.audioGraph = .liveValue // MockAudioGraph().audioGraph
    $0.audioSession = .liveValue
    $0.avAudioUnitMIDIInstrumentGenerator = await AVAudioUnitMIDIInstrumentGenerator.constant()
    $0.date = .constant(.now)
    $0.defaultDatabase = TestSupport.testDatabase()
    $0.delayDevice = .liveValue
    $0.mainQueue = .immediate
    $0.outputVolume = mockVolume.makeOutputVolume()
    $0.reverbDevice = .liveValue
  }
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
        $0.readyForUse = true
      }

      await store.receive(\.synth.lastPresetLoadFinished) {
        $0.synth.firstTimePresetLoaded = false
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

  @Test(
    .dependencies { _ in
      @Shared(.lastShowedChangesVersion) var lastShowedChangesVersion = ""
    }
  )
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
        await store.send(\.tagsList.delegate, .edit(focus: 1))
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
  func audioUnitCrashed() async throws {
    try await initialized { store in
      await store.send(\.audioUnitCrashed)
    }
  }

  @Test
  func scenePhaseChanged() async throws {
    try await initialized { store in
      await store.send(\.scenePhaseChanged, .active)
      await store.send(\.scenePhaseChanged, .inactive)
      await store.send(\.scenePhaseChanged, .background)
    }
  }

  @Test
  func volumeMonitorChanged() async throws {
    try await initialized { store in
      await store.send(\.volumeMonitor.delegate.reasonChanged, .volumeLevelIsZero) {
        $0.toastState = .volumeMonitor(reason: .volumeLevelIsZero)
        $0.keyboard.muted = true
      }

      await store.send(\.volumeMonitor.delegate.reasonChanged, .noActivePreset)

      await store.send(\.volumeMonitor.delegate.reasonChanged, .none) {
        $0.toastState = nil
        $0.keyboard.muted = false
      }
    }
  }

//  @Test
//  func destinationDismissed() async throws {
//    try await initialized { store in
//      await store.send(\.destination.dismiss)
//    }
//  }
//
//  @Test
//  func showEditPreset() async throws {
//    try await initialized { store in
//      #expect(store.state.presetsList.sections.isEmpty == false)
//      let section = store.state.presetsList.sections.first!
//      let preset = section.rows.first!.preset
//      await store.send(
//        \.presetsList.delegate,
//         .edit(
//          sectionId: 0,
//          preset: preset
//         )
//      ) {
//        $0.destination = .presetEditor(.init(sectionId: section.sectionId, preset: preset))
//      }
//
//      await store.send(\.destination.dismiss)
//    }
//  }

  @Test(
    .dependencies {
      $0.fileManager.createDirectory = { try FileManager.default.createDirectory(at: $0, withIntermediateDirectories: true) }
    },
    .snapshots(record: .failed)
  )
  func appRootViewPreview() async throws {
    try TestSupport.assertSnapshot(matching: AppRootView.preview)
  }
}
