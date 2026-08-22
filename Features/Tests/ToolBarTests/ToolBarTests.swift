// Copyright © 2025 Brad Howes. All rights reserved.

import AVFAudio
import DependenciesTestSupport
import Dependencies
import FeatureSupport
import MIDITrafficIndicator
import SnapshotTesting
import SF2LibAU
import SF2Resources
import SQLiteData
import Tagged
import Testing
import TestSupport

@testable import ToolBar

@Suite(
  .dependencies {
    $0.continuousClock = TestClock()
  },
  .snapshots(record: .failed)
)
@MainActor
struct ToolBarTests {

  fileprivate func store(
    isCompact: Bool = false,
    effectsPanelVisible: Bool = false,
    tagsListVisible: Bool = false,
    moreButtonsVisible: Bool = false
  ) async throws -> TestStoreOf<ToolBar> {
    let store = TestStoreOf<ToolBar>(
      initialState: .init(
        hasMoreButton: isCompact,
        effectsPanelVisible: effectsPanelVisible,
        showMoreButtons: moreButtonsVisible,
        tagsListVisible: tagsListVisible
      )
    ) {
      ToolBar()
    }

    return store
  }

  @Test
  func activeVoiceCountChanged() async throws {
    let store = try await store()

    await store.send(.activeVoiceCountChanged(3)) {
      $0.activeVoiceCount = 3
    }

    await store.send(.deinitialize)
    await store.receive(\.midiTrafficIndicator.deinitialize)
    await store.finish()
  }

  @Test(
    .dependencies { $0.defaultDatabase = TestSupport.testDatabase() }
  )
  func activePresetIdChanged() async throws {
    let store = try await store()

    await store.send(.activePresetIdChanged(2)) {
      $0.temporaryStatus = nil
      $0.displayName = "Font 1 Preset 2"
      $0.isFavorite = false
    }

    await store.send(.activePresetIdChanged(nil)) {
      $0.displayName = "-"
      $0.isFavorite = false
    }

    await store.send(.deinitialize)
    await store.receive(\.midiTrafficIndicator.deinitialize)
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
    await store.receive(\.midiTrafficIndicator.deinitialize)
    await store.finish()
  }

  @Test(arguments: [
    (false, false),
    (false, true),
    (true, false),
    (true, true)
  ])
  func effectsVisibilityButtonTapped(_ effectsPanelVisible: Bool, _ isCompact: Bool) async throws {
    @Shared(.effectsPanelVisible) var epv = effectsPanelVisible
    let store = try await store(isCompact: isCompact, effectsPanelVisible: effectsPanelVisible)

    #expect(store.state.hasMoreButton == isCompact)
    #expect(store.state.effectsPanelVisible == effectsPanelVisible)

    await store.send(.effectsVisibilityButtonTapped) {
      $0.$effectsPanelVisible.withLock { $0.toggle() }
    }

    await store.receive(\.delegate.effectsVisibilityChanged, !effectsPanelVisible)

    if isCompact {
      await store.send(.showMoreButtonTapped) {
        $0.showMoreButtons = true
      }
    }

    await store.send(.effectsVisibilityButtonTapped) {
      $0.$effectsPanelVisible.withLock { $0.toggle() }
      $0.showMoreButtons = isCompact
    }

    await store.receive(\.delegate.effectsVisibilityChanged, effectsPanelVisible)

    #expect(epv == effectsPanelVisible)

    await store.send(.deinitialize)
    await store.receive(\.midiTrafficIndicator.deinitialize)
    await store.finish()
  }

  @Test("helpInfoButtonTappedCompact", arguments: [
    (false, false, false),
    (false, false, true),
    (false, true, false),
    (false, true, true),
    (true, false, false),
    (true, false, true),
    (true, true, false),
    (true, true, true)
  ])
  func helpInfoButtonTappedCompact(
    _ effectsPanelVisible: Bool,
    _ tagsListVisible: Bool,
    _ moreButtonsVisible: Bool
  ) async throws {
    @Shared(.effectsPanelVisible) var epv = effectsPanelVisible
    @Shared(.tagsListVisible) var tlv = tagsListVisible

    let store = try await store(
      isCompact: true,
      effectsPanelVisible: effectsPanelVisible,
      tagsListVisible: tagsListVisible,
      moreButtonsVisible: moreButtonsVisible
    )

    var didStateChange = false

    await store.send(.helpInfoButtonTapped) {
      $0.helpInfoRestoration = .init(
        effectsPanelVisible: effectsPanelVisible,
        tagsListVisible: tagsListVisible,
        moreButtonsVisible: moreButtonsVisible
      )
    }

    if !moreButtonsVisible {
      await store.receive(\.showMoreButtonTapped) {
        $0.$effectsPanelVisible.withLock { $0 = true }
        $0.setTagsListVisible(true)
        $0.showMoreButtons = true
      }
      didStateChange = true
    }

    if !effectsPanelVisible {
      if didStateChange {
        await store.receive(\.effectsVisibilityButtonTapped)
      } else {
        await store.receive(\.effectsVisibilityButtonTapped) {
          $0.$effectsPanelVisible.withLock { $0 = true }
          $0.setTagsListVisible(true)
        }
        didStateChange = true
      }
      await store.receive(\.delegate.effectsVisibilityChanged, true)
    }

    if !tagsListVisible {
      if didStateChange {
        await store.receive(\.tagsListVisibilityButtonTapped)
      } else {
        await store.receive(\.tagsListVisibilityButtonTapped) {
          $0.$effectsPanelVisible.withLock { $0 = true }
          $0.setTagsListVisible(true)
        }
        didStateChange = true
      }
      await store.receive(\.delegate.tagsListVisibilityChanged, true)
    }

    await store.receive(\.delegate.helpInfoButtonTapped)

    await store.send(.deinitialize)
    await store.receive(\.midiTrafficIndicator.deinitialize)
    await store.finish()
  }

  @Test("helpInfoButtonTapped", arguments: [
    (false, false),
    (false, true),
    (true, false),
    (true, true)
  ])
  func helpInfoButtonTapped(
    _ effectsPanelVisible: Bool,
    _ tagsListVisible: Bool
  ) async throws {
    @Shared(.effectsPanelVisible) var epv = effectsPanelVisible
    @Shared(.tagsListVisible) var tlv = tagsListVisible

    let store = try await store(
      isCompact: false,
      effectsPanelVisible: effectsPanelVisible,
      tagsListVisible: tagsListVisible,
      moreButtonsVisible: false
    )

    var didStateChange = false

    await store.send(.helpInfoButtonTapped) {
      $0.helpInfoRestoration = .init(
        effectsPanelVisible: effectsPanelVisible,
        tagsListVisible: tagsListVisible,
        moreButtonsVisible: false
      )
    }

    if !effectsPanelVisible {
      await store.receive(\.effectsVisibilityButtonTapped) {
        $0.$effectsPanelVisible.withLock { $0 = true }
        $0.setTagsListVisible(true)
      }
      didStateChange = true
      await store.receive(\.delegate.effectsVisibilityChanged, true)
    }

    if !tagsListVisible {
      if didStateChange {
        await store.receive(\.tagsListVisibilityButtonTapped)
      } else {
        await store.receive(\.tagsListVisibilityButtonTapped) {
          $0.$effectsPanelVisible.withLock { $0 = true }
          $0.setTagsListVisible(true)
        }
        didStateChange = true
      }
      await store.receive(\.delegate.tagsListVisibilityChanged, true)
    }

    await store.receive(\.delegate.helpInfoButtonTapped)

    await store.send(.deinitialize)
    await store.receive(\.midiTrafficIndicator.deinitialize)
    await store.finish()
  }

  @Test
  func deinitialize() async throws {
    let store = try await store()
    await store.send(.deinitialize)
    await store.receive(\.midiTrafficIndicator.deinitialize)
    await store.finish()
  }

  @Test
  func lastPlayedKeyChangedIgnore() async throws {
    @Shared(.showKeyNotes) var showKeyNotes
    $showKeyNotes.withLock { $0 = false }

    let store = try await store()

    await store.send(.lastPlayedKeyChanged(.A6))
    await store.send(.deinitialize)
    await store.receive(\.midiTrafficIndicator.deinitialize)
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
    await store.receive(\.midiTrafficIndicator.deinitialize)
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
    await store.receive(\.midiTrafficIndicator.deinitialize)
    await store.finish()
  }

  @Test(
    .dependencies {
      $0.audioGraph = .liveValue
      $0.audioSession = MockAudioSession().audioSession
      $0.avAudioUnitMIDIInstrumentGenerator = await .constant()
      $0.continuousClock = .immediate
      $0.defaultDatabase = try appDatabase(loadAllPresets: false)
      $0.delayDevice = .liveValue
      $0.reverbDevice = .liveValue
    }
  )
  func monitorActiveVoiceCount() async throws {
    // guard !ProcessInfo.processInfo.isOnGithub else { return }

    let synth = TestStore(initialState: Synth.State()) { Synth() }
    await synth.send(.initialize)

    await synth.withExhaustivity(.off(showSkippedAssertions: false)) {
      await synth.receive(\.synthAudioUnitCreated) {
        $0.audioSessionActivated = true
      }
    }

    @Dependency(\.avAudioUnitMIDIInstrumentGenerator) var avAudioUnitMIDIInstrumentGenerator
    await synth.receive(\.delegate.running, avAudioUnitMIDIInstrumentGenerator.generate()!)

    await synth.send(\.activePresetIdChanged, 2) {
      $0.loadedSoundFontId = 1
      $0.loadedPresetIndex = 1
      $0.activePresetId = 2
    }

    await synth.receive(\.lastPresetLoadFinished, timeout: .seconds(5)) {
      $0.firstTimeLoading = false
    }

    let store = try await store()

    await store.send(.audioUnitCreated(synth.state.avAudioUnit!)) {
      $0.temporaryStatus = nil
    }

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
    await store.receive(\.midiTrafficIndicator.deinitialize)
    await store.finish()
  }

  @Test(arguments: [false, true])
  func settingsButtonTapped(_ isCompact: Bool) async throws {
    let store = try await store(isCompact: isCompact)

    if isCompact {
      await store.send(.showMoreButtonTapped) { $0.showMoreButtons = true }
      await store.send(.settingsButtonTapped)
    } else {
      await store.send(.settingsButtonTapped)
    }

    await store.receive(\.delegate.settingsButtonTapped)

    await store.send(.deinitialize)
    await store.receive(\.midiTrafficIndicator.deinitialize)
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
    await store.receive(\.midiTrafficIndicator.deinitialize)
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
    await store.receive(\.midiTrafficIndicator.deinitialize)
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
    await store.receive(\.midiTrafficIndicator.deinitialize)
    await store.finish()
  }

  @Test
  func showMoreButtonTapped() async throws {
    let store = try await store(isCompact: true)

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
    await store.receive(\.midiTrafficIndicator.deinitialize)
    await store.finish()
  }

  @Test
  func statusTextTappedTwice() async throws {
    @Dependency(\.continuousClock) var clock
    let testClock = clock as! TestClock<Duration>
    let store = try await store()

    await store.send(.statusTextTapped(count: 2)) { $0.temporaryStatus = .panic }
    await store.receive(\.delegate.panic)

    await testClock.run()
    await store.receive(\.clearTemporaryStatus) { $0.temporaryStatus = nil }

    await store.send(.deinitialize)
    await store.receive(\.midiTrafficIndicator.deinitialize)
    await store.finish()
  }

  @Test
  func statusTextTappedOnce() async throws {
    let store = try await store()

    await store.send(.statusTextTapped(count: 1))
    await store.receive(\.delegate.presetNameTapped)

    await store.send(.deinitialize)
    await store.receive(\.midiTrafficIndicator.deinitialize)
    await store.finish()
  }

  @Test(arguments: [false, true])
  func slidingKeyboardButtonTappedInitFalse(_ keyboardSlidsInit: Bool) async throws {
    @Shared(.keyboardSlides) var keyboardSlides = keyboardSlidsInit

    let store = try await store()
    #expect(store.state.keyboardSlides == keyboardSlidsInit)

    await store.send(.slidingKeyboardButtonTapped) {
      $0.$keyboardSlides.withLock { $0.toggle() }
    }

    await store.send(.slidingKeyboardButtonTapped) {
      $0.$keyboardSlides.withLock { $0.toggle() }
    }

    #expect(keyboardSlides == keyboardSlidsInit)

    await store.send(.deinitialize)
    await store.receive(\.midiTrafficIndicator.deinitialize)
    await store.finish()
  }

  @Test(arguments: [
    (false, false),
    (false, true),
    (true, false),
    (true, true)
  ])
  func tagsVisibilityButtonTapped(_ tagsListVisible: Bool, isCompact: Bool) async throws {
    @Shared(.tagsListVisible) var tlv = tagsListVisible

    let store = try await store(isCompact: isCompact, tagsListVisible: tagsListVisible)
    #expect(store.state.tagsListVisible == tagsListVisible)

    await store.send(.tagsListVisibilityButtonTapped) {
      $0.tagsListVisibleToggle()
    }
    await store.receive(\.delegate.tagsListVisibilityChanged, !tagsListVisible)

    await store.send(.tagsListVisibilityButtonTapped) {
      $0.tagsListVisibleToggle()
    }
    await store.receive(\.delegate.tagsListVisibilityChanged, tagsListVisible)

    #expect(tlv == tagsListVisible)

    await store.send(.deinitialize)
    await store.receive(\.midiTrafficIndicator.deinitialize)
    await store.finish()
  }

  @Test
  func previewWithFixedKeyboard() async throws {
    withDependencies {
      $0.mainQueue = .immediate
      $0.defaultDatabase = previewDatabase()
    } operation: {
      @Shared(.keyboardSlides) var keyboardSlides
      $keyboardSlides.withLock { $0 = false }
      withSnapshotTesting(record: .failed) {
        let view = ToolBarView(
          store: Store(
            initialState: .init(
              showMoreButtons: true
            )
          ) {
            ToolBar()
          }, isAUv3: false)
        TestSupport.assertSnapshot(matching: view)
      }
    }
  }

  @Test
  func previewWithFSlidingKeyboard() async throws {
    withDependencies {
      $0.mainQueue = .immediate
      $0.defaultDatabase = previewDatabase()
    } operation: {
      @Shared(.keyboardSlides) var keyboardSlides
      $keyboardSlides.withLock { $0 = true }
      withSnapshotTesting(record: .failed) {
        let view = ToolBarView(
          store: Store(
            initialState: .init(
              showMoreButtons: true
            )
          ) {
            ToolBar()
          }, isAUv3: false)
        TestSupport.assertSnapshot(matching: view)
      }
    }
  }

  @Test
  func preview() async throws {
    withDependencies {
      $0.mainQueue = .immediate
      $0.defaultDatabase = previewDatabase()
    } operation: {
      withSnapshotTesting(record: .failed) {
        TestSupport.assertSnapshot(matching: ToolBarView.preview())
      }
    }
  }
}
