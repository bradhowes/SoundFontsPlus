// Copyright © 2025 Brad Howes. All rights reserved.

import AVFAudio
import DependenciesTestSupport
import FeatureSupport
import SnapshotTesting
import SF2LibAU
import SF2Resources
import Testing
import TestSupport

@testable import ToolBar

@Suite(
  .dependencies {
    $0.continuousClock = TestClock()
    $0.mainQueue = .immediate
  },
  .snapshots(record: .failed)
)
@MainActor
struct ToolBarTests {
  @Shared(.activeState) var activeState = .default

  fileprivate func store() async throws -> TestStoreOf<ToolBar> {
    TestStoreOf<ToolBar>(initialState: .init()) {
      ToolBar()
    }
  }

  @Test
  func activeVoiceCountChanged() async throws {
    let store = try await store()

    await store.send(.activeVoiceCountChanged(3)) {
      $0.activeVoiceCount = 3
    }

    await store.send(.deinitialize)
    await store.finish()
  }

  @Test(
    .dependencies { $0.defaultDatabase = TestSupport.testDatabase() }
  )
  func activePresetIdChanged() async throws {
    @Shared(.activeState) var activeState
    let store = try await store()

    await store.send(.activePresetIdChanged(2)) {
      $0.preset = .init(
        id: Tagged(rawValue: 2),
        index: 1,
        bank: 0,
        program: 1,
        originalName: "Original Preset 2",
        soundFontId: Tagged(rawValue: 1),
        displayName: "Font 1 Preset 2",
        notes: "",
        kind: .preset
      )
    }

    await store.send(.activePresetIdChanged(nil)) {
      $0.preset = nil
    }

    await store.send(.deinitialize)
    await store.finish()
  }

  @Test
  func editPresetVisibility() async throws {
    let store = try await store()

    await store.send(.presetsVisibilityButtonTapped) {
      $0.editingPresetVisibility = true
    }

    await store.receive(\.delegate.editingPresetVisibilityChanged, true)

    await store.send(.presetsVisibilityButtonTapped) {
      $0.editingPresetVisibility = false
    }

    await store.receive(\.delegate.editingPresetVisibilityChanged, false)

    await store.send(.deinitialize)
    await store.finish()
  }

  @Test(arguments: [false, true]) func effectsVisibilityButtonTapped(_ initValue: Bool) async throws {
    @Shared(.effectsPanelVisible) var effectsPanelVisible = initValue
    let store = try await store()
    #expect(store.state.effectsPanelVisible == initValue)

    await store.send(.effectsVisibilityButtonTapped) {
      $0.effectsPanelVisible.toggle()
    }

    await store.receive(\.delegate.effectsVisibilityChanged, !initValue)

    await store.send(.showMoreButtonTapped) {
      $0.showMoreButtons.toggle()
    }

    await store.send(.effectsVisibilityButtonTapped) {
      $0.effectsPanelVisible.toggle()
      $0.showMoreButtons = false
    }

    await store.receive(\.delegate.effectsVisibilityChanged, initValue)

    #expect(effectsPanelVisible == initValue)

    await store.send(.deinitialize)
    await store.finish()
  }

  @Test
  func helpButtonTapped() async throws {
    let store = try await store()

    await store.send(.helpButtonTapped)

    await store.send(.deinitialize)
    await store.finish()
  }

  @Test
  func deinitialize() async throws {
    let store = try await store()
    await store.send(.deinitialize)
    await store.finish()
  }

  @Test
  func lastPlayedKeyChangedIgnore() async throws {
    @Shared(.showKeyNotes) var showKeyNotes
    $showKeyNotes.withLock { $0 = false }

    let store = try await store()

    await store.send(.lastPlayedKeyChanged(.A6))
    await store.send(.deinitialize)
    await store.finish()
  }

  @Test
  func lastPlayedKeyChangedShow() async throws {
    @Shared(.showKeyNotes) var showKeyNotes
    $showKeyNotes.withLock { $0 = true }

    let store = try await store()

    await store.send(.lastPlayedKeyChanged(.A6)) {
      $0.temporaryStatus = .lastPlayedKey(Note.A6.fullLabel(withSolfege: false))
    }

    await store.send(.deinitialize)
    await store.finish()
  }

  @Test
  func lastPlayedKeyChangedShowSolfege() async throws {
    @Shared(.showSolfegeTags) var showSolfegeTags
    $showSolfegeTags.withLock { $0 = true }

    let store = try await store()

    await store.send(.lastPlayedKeyChanged(.A6)) {
      $0.temporaryStatus = .lastPlayedKey(Note.A6.fullLabel(withSolfege: true))
    }

    await store.send(.deinitialize)
    await store.finish()
  }

  @Test(
    .dependencies {
      $0.audioGraph = .liveValue
      $0.audioSession = .liveValue
      $0.avAudioUnitMIDIInstrumentGenerator = await AVAudioUnitMIDIInstrumentGenerator.constant()
      $0.continuousClock = .immediate
      $0.defaultDatabase = try appDatabase(loadAllPresets: false)
      $0.delayDevice = .liveValue
      $0.reverbDevice = .liveValue
    }
  )
  func monitorActiveVoiceCount() async throws {
    guard !ProcessInfo.processInfo.isOnGithub else { return }

    // Uff. Replication here of synth init in order to have an audio unit that will emit a voice count change.
    @Dependency(\.avAudioUnitMIDIInstrumentGenerator) var avAudioUnitMIDIInstrumentGenerator
    let avAudioUnit = try #require(await avAudioUnitMIDIInstrumentGenerator.generate())

    let synth = TestStore(initialState: Synth.State()) { Synth() }
    await synth.send(.initialize)

    await synth.receive(\.synthAudioUnitCreated) {
      $0.audioSessionActivated = true
      $0.avAudioUnit = avAudioUnit
    }
    await synth.receive(\.delegate.audioUnitCreated)
    await synth.receive(\.delegate.running)
    await synth.send(\.activePresetIdChanged, 2) {
      $0.loadedSoundFontId = 1
      $0.loadedPresetIndex = 1
    }
    await synth.receive(\.lastPresetLoadFinished, timeout: .seconds(5)) {
      $0.firstTimePresetLoaded = false
    }

    let store = try await store()

    await store.send(.audioUnitCreated(avAudioUnit))

    await synth.send(\.playNote)

    await store.withExhaustivity(.off(showSkippedAssertions: false)) {

      // This is a bit hacky due to using a real AUv3 component.
      await store.receive(\.activeVoiceCountChanged, timeout: .seconds(10))
      if store.state.activeVoiceCount > 0 {
        await store.receive(\.activeVoiceCountChanged, timeout: .seconds(10))
      }
    }

    await synth.send(.deinitialize)
    await store.send(.deinitialize)
    await store.finish()
  }

  @Test
  func settingsButtonTapped() async throws {
    let store = try await store()

    await store.send(.showMoreButtonTapped) {
      $0.showMoreButtons = true
    }

    await store.send(.settingsButtonTapped) {
      $0.showMoreButtons = false
    }

    await store.receive(\.delegate.settingsButtonTapped)

    await store.send(.deinitialize)
    await store.finish()
  }

  @Test
  func setVisibleKeyRange() async throws {
    let store = try await store()

    await store.send(.setVisibleKeyRange(lowest: .A1, highest: .B3)) {
      $0.lowestKey = .A1
      $0.highestKey = .B3
    }

    await store.send(.deinitialize)
    await store.finish()
  }

  @Test
  func shiftKeyboardDownButtonTapped() async throws {
    let store = try await store()

    await store.send(.setVisibleKeyRange(lowest: .C5, highest: .B5)) {
      $0.lowestKey = .C5
      $0.highestKey = .B5
    }

    await store.send(.shiftKeyboardDownButtonTapped) {
      $0.lowestKey = .C4
      $0.highestKey = .B4
    }

    await store.receive(\.delegate.visibleKeyRangeChanged)

    await store.send(.deinitialize)
    await store.finish()
  }

  @Test
  func shiftKeyboardUpButtonTapped() async throws {
    let store = try await store()

    await store.send(.setVisibleKeyRange(lowest: .A2, highest: .C4)) {
      $0.lowestKey = .A2
      $0.highestKey = .C4
    }

    await store.send(.shiftKeyboardUpButtonTapped) {
      $0.lowestKey = .C4
      $0.highestKey = .init(midiNoteValue: 75)
    }

    await store.receive(\.delegate.visibleKeyRangeChanged)

    await store.send(.deinitialize)
    await store.finish()
  }

  @Test
  func showMoreButtonTapped() async throws {
    let store = try await store()

    await store.send(.showMoreButtonTapped) {
      $0.showMoreButtons = true
    }

    await store.send(.presetsVisibilityButtonTapped) {
      $0.editingPresetVisibility = true
    }

    await store.receive(\.delegate.editingPresetVisibilityChanged, true)

    await store.send(.showMoreButtonTapped) {
      $0.showMoreButtons = false
      $0.editingPresetVisibility = false
    }

    await store.receive(\.delegate.editingPresetVisibilityChanged, false)

    await store.send(.deinitialize)
    await store.finish()
  }

  @Test(arguments: [false, true]) func slidingKeyboardButtonTappedInitFalse(_ initValue: Bool) async throws {
    @Shared(.keyboardSlides) var keyboardSlides = initValue

    let store = try await store()
    #expect(store.state.keyboardSlides == initValue)

    await store.send(.slidingKeyboardButtonTapped) {
      $0.$keyboardSlides.withLock { $0.toggle() }
    }

    await store.send(.slidingKeyboardButtonTapped) {
      $0.$keyboardSlides.withLock { $0.toggle() }
    }

    #expect(keyboardSlides == initValue)

    await store.send(.deinitialize)
    await store.finish()
  }

  @Test(arguments: [false, true]) func tagsVisibilityButtonTapped(_ initValue: Bool) async throws {
    @Shared(.tagsListVisible) var tagsListVisible = initValue

    let store = try await store()
    #expect(store.state.tagsListVisible == initValue)

    await store.send(.tagsListVisibilityButtonTapped) {
      $0.tagsListVisible.toggle()
    }
    await store.receive(\.delegate.tagsListVisibilityChanged, !initValue)

    await store.send(.tagsListVisibilityButtonTapped) {
      $0.tagsListVisible.toggle()
    }
    await store.receive(\.delegate.tagsListVisibilityChanged, initValue)

    #expect(tagsListVisible == initValue)

    await store.send(.deinitialize)
    await store.finish()
  }

  @Test
  func preview() async throws {
    try withSnapshotTesting(record: .failed) {
      try TestSupport.assertSnapshot(matching: ToolBarView.preview)
    }
  }
}
