// Copyright © 2025 Brad Howes. All rights reserved.

import DependenciesTestSupport
import FeatureSupport
import Models
import Settings
import SnapshotTesting
import Testing
import TestSupport

@testable import Presets
@testable import Root

@Suite(
  .dependencies {
    let mockVolume = OutputVolumeFlipFlop()
    $0.outputVolume = mockVolume.makeOutputVolume()
    $0.defaultDatabase = try appDatabase()
    $0.mainQueue = .immediate
    $0.audioSession = .liveValue
    $0.date = .constant(.now)
  },
  .snapshots(record: .failed)
)
@MainActor
struct RootTests {

  func store() -> TestStoreOf<Root> {
    @Shared(.activeState) var activeState = .default
    return TestStoreOf<Root>(initialState: .init()) {
      Root()
    }
  }

  func initialized(_ test: (TestStoreOf<Root>) async throws -> Void) async throws {
    let store = store()
    try await store.withExhaustivity(.off(showSkippedAssertions: false)) {
      await store.send(.initialize)
      await store.receive(\.activePresetIdChanged)
      await store.receive(\.synth.synthAudioUnitCreated)
      await store.receive(\.synth.activePresetIdChanged)
      await store.receive(\.synth.delegate, .running)
      await store.receive(\.toolBar.activeVoiceCountChanged)

      try await test(store)
    }

    await store.send(.deinitialize)
    await store.finish()
  }

  @Test func disableIdleTimer() throws {
    @Shared(.disableIdleTimer) var disableIdleTimer = false
    #expect(!UIKit.UIApplication.shared.isIdleTimerDisabled)

    Root.disableIdleTimer()
    #expect(!UIKit.UIApplication.shared.isIdleTimerDisabled)

    $disableIdleTimer.withLock { $0 = true }
    Root.disableIdleTimer()
    // NOTE: does not appear to work in test environment
    // #expect(UIKit.UIApplication.shared.isIdleTimerDisabled)
  }

  @Test func initialize() async throws {
    let store = store()

    await store.withExhaustivity(.off(showSkippedAssertions: false)) {
      await store.send(.initialize)

      await store.receive(\.activePresetIdChanged)
      await store.receive(\.synth.synthAudioUnitCreated)
      await store.receive(\.synth.activePresetIdChanged)
      await store.receive(\.synth.delegate, .running)
      await store.receive(\.toolBar.activeVoiceCountChanged)
    }

    await store.send(.deinitialize)
    await store.finish()
  }

  @Test func processPresetsSplitAction() async throws {
    try await initialized { store in
      @Shared(.fontsAndPresetsSplitPosition) var fontsAndPresetsSplitPosition
      #expect(fontsAndPresetsSplitPosition == 0.5)
      await store.send(\.presetsSplit.delegate, .stateChanged(panesVisible: .both, position: 0.3))
      #expect(fontsAndPresetsSplitPosition == 0.3)
    }
  }

  @Test func processTagsSplitAction() async throws {
    try await initialized { store in
      @Shared(.tagsListVisible) var tagsListVisible
      @Shared(.fontsAndTagsSplitPosition) var fontsAndTagsSplitPosition
      #expect(tagsListVisible == false)
      #expect(fontsAndTagsSplitPosition == 0.4)
      await store.send(\.tagsSplit.delegate, .stateChanged(panesVisible: .both, position: 0.5))
      #expect(tagsListVisible == true)
      #expect(fontsAndTagsSplitPosition == 0.5)
    }
  }

  @Test func refreshPresets() async throws {
    try await initialized { store in
      let soundFont = SoundFont.with(id: 1)!
      await store.send(\.soundFontsList.delegate, .edit(soundFont))
      #expect(store.state.destination != nil)
      await store.send(\.destination.presented.soundFontEditor.delegate, .refreshPresets)
    }
  }

  @Test func showChanges() async throws {
    try await initialized { store in
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

//  @Test func showPresetEditor() async throws {
//    try await initialized { store in
//      await store.send(\.presetsList, .fetchPresets)
//      let preset = Preset.with(id: 1)
//      await store.send(\.presetsList.sections, .element(id: 10000, action: .rows(.element(id: 1, action: .delegate(.editPreset(preset!))))))
//      #expect(store.state.destination != nil)
//    }
//  }

  @Test func showSoundFontEditor() async throws {
    try await initialized { store in
      let soundFont = SoundFont.with(id: 1)!
      await store.send(\.soundFontsList.delegate, .edit(soundFont))
      #expect(store.state.destination != nil)
    }
  }

  @Test func showTagsEditor() async throws {
    try await initialized { store in
      await store.send(\.tagsList.delegate, .edit(1))
    }
  }

  @Test func showTutorial() async throws {
    try await initialized { store in
      @Shared(.showedTutorial) var showedTutorial
      await store.send(\.toolBar.delegate, .settingsButtonTapped)
      #expect(store.state.destination != nil)
      let settings = store.state.destination
      #expect(showedTutorial == false)
      await store.send(\.destination.settings.delegate, .showTutorial)
      #expect(store.state.destination != settings)
      #expect(showedTutorial == true)
    }
  }

  @Test func rootViewPreview() async throws {
    try TestSupport.assertSnapshot(matching: RootView.preview)
  }
}
