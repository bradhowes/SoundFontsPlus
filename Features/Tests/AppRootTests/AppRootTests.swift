// Copyright © 2025 Brad Howes. All rights reserved.

import AppReview
import AUv3Controls
import AVFAudio
import BRHSplitView
import DelayEffect
import DependenciesTestSupport
import FeatureSupport
import Keyboard
import MIDITrafficIndicator
import Models
import MorkAndMIDI
import ReverbEffect
import Settings
import SF2LibAU
import SF2Resources
import SnapshotTesting
import SoundFonts
import SQLiteData
import Tagged
import Tags
import Testing
import TestSupport
import ToolBar
import Tutorial
import VolumeMonitor

@testable import Presets
@testable import AppRoot

@Suite(
  .dependencies {
    let mockVolume = OutputVolumeFlipFlop()
    $0.audioGraph = .liveValue
    $0.audioSession = .liveValue
    $0.avAudioUnitMIDIInstrumentGenerator = .liveValue
    $0.continuousClock = TestClock<Duration>()
    $0.date = .constant(.now)
    $0.defaultDatabase = try appDatabase(fonts: [SF2ResourceTag.fluidFont], loadAllPresets: false)
    $0.delayDevice = .liveValue
    $0.fileManager = .liveValue
    $0.outputVolume = mockVolume.makeOutputVolume()
    $0.reverbDevice = .liveValue
    $0.uuid = .incrementing
  },
  .serialized // due to SF2LibAU creation
)
@MainActor
struct AppRootTests {

  @Shared(.disableIdleTimer) var disableIdleTimer = false
  @Shared(.effectsPanelVisible) var effectsPanelVisible = false
  @Shared(.fontsAndPresetsSplitPosition) var fontsAndPresetsSplitPosition
  @Shared(.fontsAndTagsSplitPosition) var fontsAndTagsSplitPosition
  @Shared(.lastShowedChangesVersion) var lastShowedChangesVersion = ""
  @Shared(.showedTutorial) var showedTutorial
  @Shared(.tagsListVisible) var tagsListVisible = false

  func store(showedTutorial: Bool = true) -> TestStoreOf<AppRoot> {
    $showedTutorial.withLock { $0 = showedTutorial }
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

    let store = store(showedTutorial: showedTutorial)

    await store.send(.initialize)
    await store.receive(\.synth.initialize)

    await store.withExhaustivity(.off(showSkippedAssertions: false)) {
      await store.receive(\.synth.synthAudioUnitCreated) {
        $0.synth.audioSessionActivated = true
        // $0.synth.avAudioUnit = avAudioUnit
      }
    }

    let avAudioUnit = try #require(store.state.synth.avAudioUnit)

    await store.receive(\.synth.delegate.running, avAudioUnit) {
      $0.toolBar.temporaryStatus = .startup
      $0.toastState = nil
      $0.readyForUse = true
      $0.avAudioUnit = avAudioUnit
    }

    await store.receive(\.toolBar.audioUnitCreated, avAudioUnit) {
      $0.toolBar.temporaryStatus = nil
    }
    await store.receive(\.keyboard.midiInstrumentCreated, avAudioUnit) { $0.keyboard.midiInstrument = avAudioUnit }

    await store.receive(\.volumeMonitor.start) { $0.volumeMonitor.reason = .noActivePreset }
    await store.receive(\.appReview.ask)
    await store.receive(\.delayEffect.activePresetIdChanged, 1) { $0.delayEffect.activePresetId = 1 }
    await store.receive(\.keyboard.activePresetIdChanged, 1)
    await store.receive(\.reverbEffect.activePresetIdChanged, 1) { $0.reverbEffect.activePresetId = 1 }
    await store.receive(\.soundFontsList.selectedIsNowActivated)
    await store.receive(\.synth.activePresetIdChanged, 1) {
      $0.synth.activePresetId = 1
      $0.synth.loadedPresetIndex = 0
      $0.synth.loadedSoundFontId = 1
    }
    let preset = Preset.with(id: 1)
    await store.receive(\.toolBar.activePresetIdChanged, 1) {
      $0.toolBar.temporaryStatus = nil
      $0.toolBar.displayName = preset?.displayName ?? ""
      $0.toolBar.isFavorite = preset?.isFavorite ?? false
    }
    await store.receive(\.volumeMonitor.activePresetIdChanged, 1) {
      $0.volumeMonitor.activePresetId = 1
      $0.volumeMonitor.reason = nil
    }
    await store.receive(\.toolBar.midiTrafficIndicator.initialize)
    await store.receive(\.volumeMonitor.delegate.reasonChanged, .noActivePreset) {
      $0.keyboard.muted = false
      $0.toastState = .noActivePreset
    }
    await store.receive(\.delayEffect.enabled.setValue, false)
    await store.receive(\.delayEffect.time.setValueSilently, 0.5)
    await store.receive(\.delayEffect.feedback.setValueSilently, 25.0)
    await store.receive(\.delayEffect.cutoff.setValueSilently, 12000.0)
    await store.receive(\.delayEffect.wetDryMix.setValueSilently, 50.0)
    await store.receive(\.reverbEffect.enabled.setValue, false)
    await store.receive(\.reverbEffect.wetDryMix.setValueSilently, 50.0)
    await store.receive(\.soundFontsList.delegate.presetSourceChanged, .active(1))
    await store.receive(\.volumeMonitor.delegate.reasonChanged, nil) { $0.toastState = nil }
    await store.receive(\.keyboard.outputVolumeStateChanged, .muted) { $0.keyboard.muted = true }
    await store.receive(\.delayEffect.time.track.valueChanged, 0.5)
    await store.receive(\.delayEffect.feedback.track.valueChanged, 25.0)
    await store.receive(\.delayEffect.cutoff.track.valueChanged, 12000.0)
    await store.receive(\.delayEffect.wetDryMix.track.valueChanged, 50.0)
    await store.receive(\.reverbEffect.wetDryMix.track.valueChanged, 50.0)
    await store.receive(\.presetsList.presetSourceChanged, .active(1)) { $0.presetsList.scrollToTarget = .preset(1) }
    await store.receive(\.keyboard.outputVolumeStateChanged, .unmuted) { $0.keyboard.muted = false }
    await store.receive(\.synth.lastPresetLoadFinished) { $0.synth.firstTimeLoading = false }

    try await store.withExhaustivity(exhaustivity) {
      try await closure(store)
    }

    await store.send(.deinitialize)

    await store.receive(\.delayEffect.deinitialize)
    await store.receive(\.keyboard.deinitialize)
    await store.receive(\.presetsList.deinitialize)
    await store.receive(\.reverbEffect.deinitialize)
    await store.receive(\.soundFontsList.deinitialize)
    await store.receive(\.synth.deinitialize)
    await store.receive(\.tagsList.deinitialize)
    await store.receive(\.toolBar.deinitialize)
    await store.receive(\.volumeMonitor.stop)
    await store.receive(\.toolBar.midiTrafficIndicator.deinitialize)

    await store.finish()
  }

  @Test
  func initialize() async throws {
    try await initialized { _ in }
  }

  @Test(
    .dependencies {
      let midi = MIDIProvider.makeMIDI(clientName: "BlahBlah")
      $0.midiProvider = .init(midiProvider: { midi })
    }
  )
  func initializeWithMIDI() async throws {
    try await initialized { _ in }
  }

  @Test
  func activePresetIdChangedDuplicate() async throws {
    try await initialized { store in
      #expect(store.state.readyForUse == true)
      // Ignore duplicate same preset ID.
      await store.send(\.activePresetIdChanged, 1)
    }
  }

  @Test
  func activePresetIdChangedDifferent() async throws {
    try await initialized { store in
      #expect(store.state.readyForUse == true)

      await store.send(\.activePresetIdChanged, 2)

      await store.receive(\.appReview.ask)
      await store.receive(\.delayEffect.activePresetIdChanged, 2) { $0.delayEffect.activePresetId = 2 }
      await store.receive(\.keyboard.activePresetIdChanged, 2)
      await store.receive(\.reverbEffect.activePresetIdChanged, 2) { $0.reverbEffect.activePresetId = 2 }
      await store.receive(\.soundFontsList.selectedIsNowActivated)
      await store.receive(\.synth.activePresetIdChanged, 2) {
        $0.synth.activePresetId = 2
        $0.synth.loadedPresetIndex = 1
        $0.synth.loadedSoundFontId = 1
      }
      let preset = Preset.with(id: 2)
      await store.receive(\.toolBar.activePresetIdChanged, 2) {
        $0.toolBar.temporaryStatus = nil
        $0.toolBar.displayName = preset?.displayName ?? ""
        $0.toolBar.isFavorite = preset?.isFavorite ?? false
      }
      await store.receive(\.volumeMonitor.activePresetIdChanged, 2) {
        $0.volumeMonitor.activePresetId = 2
        $0.volumeMonitor.reason = nil
      }
      await store.receive(\.soundFontsList.delegate.presetSourceChanged, .active(1))
      await store.receive(\.presetsList.presetSourceChanged, .active(1))

      await store.receive(\.synth.lastPresetLoadFinished)
    }
  }

  @Test
  func synthStopped() async throws {
    try await initialized { store in
      await store.send(\.synth.delegate.stopped)
      await store.receive(\.volumeMonitor.stop)
    }
  }

  @Test
  func idleTimerCanBeDisabled() throws {
    #expect(!UIKit.UIApplication.shared.isIdleTimerDisabled)

    AppRoot.disableIdleTimer()
    #expect(!UIKit.UIApplication.shared.isIdleTimerDisabled)

    $disableIdleTimer.withLock { $0 = true }
    AppRoot.disableIdleTimer()
  }

  @Test
  func processKeyboardAction() async throws {
    @Dependency(\.continuousClock) var clock
    let testClock = clock as! TestClock<Duration>
    try await initialized { store in
      await store.send(\.keyboard.delegate.noteOn, .C4)
      await store.receive(\.toolBar.lastPlayedKeyChanged, .C4) {
        $0.toolBar.temporaryStatus = .lastPlayedKey("C4")
      }
      await testClock.run()
      await store.receive(\.toolBar.clearTemporaryStatus) {
        $0.synth.firstTimeLoading = false
        $0.toolBar.temporaryStatus = nil
      }
    }
  }

  @Test
  func processPresetsSplitAction() async throws {
    try await initialized { store in
      #expect(fontsAndPresetsSplitPosition == 0.5)
      await store.send(\.fontsAndPresetsSplit.delegate, .stateChanged(panesVisible: .both, position: 0.3))
      #expect(fontsAndPresetsSplitPosition == 0.3)
    }
  }

  @Test
  func processTagsSplitAction() async throws {
    try await initialized { store in
      #expect(tagsListVisible == false)
      #expect(fontsAndTagsSplitPosition == 0.4)
      await store.send(\.fontsAndTagsSplit.delegate, .stateChanged(panesVisible: .both, position: 0.5)) {
        $0.toolBar.tagsListVisibleToggle()
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
      await store.send(\.toolBar.delegate, .settingsButtonTapped)
      #expect(store.state.destination != nil)
      let settings = store.state.destination
      #expect(lastShowedChangesVersion == "16.0")
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
      await store.receive(\.synth.acquireAudioSession)
      await store.send(\.scenePhaseChanged, .inactive)
      await store.receive(\.synth.releaseAudioSession)
      await store.send(\.scenePhaseChanged, .background)
      await store.receive(\.synth.releaseAudioSession)
    }
  }

  @Test
  func volumeMonitorChanged() async throws {
    try await initialized { store in
      await store.send(\.volumeMonitor.delegate.reasonChanged, .volumeLevelIsZero) {
        $0.toastState = .volumeLevelIsZero
      }

      await store.receive(\.keyboard.outputVolumeStateChanged, .muted) { $0.keyboard.muted = true }
      await store.send(\.volumeMonitor.delegate.reasonChanged, .noActivePreset)
      await store.receive(\.keyboard.outputVolumeStateChanged, .muted)
      await store.send(\.volumeMonitor.delegate.reasonChanged, .none) { $0.toastState = nil }
      await store.receive(\.keyboard.outputVolumeStateChanged, .unmuted) { $0.keyboard.muted = false }
    }
  }

  @Test
  func showEditPreset() async throws {
    try await initialized { store in
      #expect(store.state.presetsList.sections.isEmpty == false)
      let section = store.state.presetsList.sections.first!
      let preset = Preset.with(id: 1)! // section.rows.first!.preset
      await store.send(
        \.presetsList.delegate,
         .edit(
          sectionId: section.id,
          preset: preset
         )
      ) {
        $0.destination = .presetEditor(
          .init(
            sectionId: section.id,
            preset: preset,
            isActive: true,
            audioUnit: $0.avAudioUnit?.auAudioUnit
          )
        )
      }

      await store.send(\.destination.dismiss) {
        $0.destination = nil
      }

      await store.receive(\.appReview.ask)
      await store.receive(\.presetsList.updateFetchAllQuery)
      await store.receive(\.toolBar.activePresetIdChanged, 1)
      await store.receive(\.presetsList, .rowsSourceUpdated(source: PresetInfo.visible(for: 1), showActive: false))
    }
  }

  @Test
  func showSettings() async throws {
    try await initialized { store in
      // TODO: use MIDI mocks to enable exhaustivity
      _ = await store.withExhaustivity(.off(showSkippedAssertions: false)) {
        await store.send(\.toolBar.delegate.settingsButtonTapped)
      }
      await store.send(\.destination.dismiss) {
        $0.destination = nil
      }
      await store.receive(\.appReview.ask)
      // await store.receive(\.presetsList.updateFetchAllQuery)
      // await store.receive(\.presetsList, .rowsUpdated(presets: Preset.visible(for: 1), showActive: false))
    }
  }

  @Test
  func editingPresetVisibilityChanged() async throws {
    try await initialized { store in
      await store.send(\.toolBar.delegate.editingPresetVisibilityChanged, true)
      await store.receive(\.presetsList.editingVisibilityChanged, true) { $0.presetsList.editingVisibility = true }
      await store.receive(\.presetsList.rowsSourceUpdated)
      await store.send(\.toolBar.delegate.editingPresetVisibilityChanged, false)
      await store.receive(\.presetsList.editingVisibilityChanged, false) { $0.presetsList.editingVisibility = false }
      await store.receive(\.presetsList.rowsSourceUpdated)
    }
  }

  @Test
  func effectsVisibilityChanged() async throws {
    try await initialized { store in
      await store.send(\.toolBar.delegate.effectsVisibilityChanged, true) {
        $0.toolBar.$effectsPanelVisible.withLock { $0 = true }
      }
      #expect(effectsPanelVisible == true)
      await store.send(\.toolBar.delegate.effectsVisibilityChanged, false) {
        $0.toolBar.$effectsPanelVisible.withLock { $0 = false }
      }
      #expect(effectsPanelVisible == false)
    }
  }

  @Test
  func presetNameTapped() async throws {
    try await initialized { store in
      await store.send(\.toolBar.delegate.presetNameTapped)
      await store.receive(\.appReview.ask)
      await store.receive(\.soundFontsList.showActiveSoundFont)
      await store.receive(\.soundFontsList.delegate.presetSourceChanged, .active(1))
      await store.receive(\.presetsList.presetSourceChanged, .active(1))
    }
  }

  @Test
  func panic() async throws {
    try await initialized { store in
      await store.send(\.keyboard.visualizeMIDINote, .on(.C4)) { $0.keyboard.noteCounters[60] = 1 }
      await store.send(\.toolBar.delegate.panic)
      await store.receive(\.keyboard.allOff) { $0.keyboard.noteCounters[60] = 0 }
    }
  }

  @Test
  func tagsListVisibilityChanged() async throws {
    try await initialized { store in
      await store.send(\.toolBar.delegate.tagsListVisibilityChanged, true) {
        $0.toolBar.tagsListVisibleToggle()
      }
      await store.receive(\.fontsAndTagsSplit.updatePanesVisibility, .init(rawValue: 3)) {
        $0.fontsAndTagsSplit.panesVisible = .init(rawValue: 3)
      }
      await store.receive(\.fontsAndTagsSplit.delegate, .stateChanged(panesVisible: .init(rawValue: 3), position: 0.4))
      await store.send(\.toolBar.delegate.tagsListVisibilityChanged, false) {
        $0.toolBar.tagsListVisibleToggle()
      }
      await store.receive(\.fontsAndTagsSplit.updatePanesVisibility, .init(rawValue: 1)) {
        $0.fontsAndTagsSplit.panesVisible = .init(rawValue: 1)
      }
      await store.receive(\.fontsAndTagsSplit.delegate, .stateChanged(panesVisible: .init(rawValue: 1), position: 0.4))
    }
  }

  @Test
  func visibleKeyRangeChanged() async throws {
    try await initialized { store in
      await store.send(\.toolBar.delegate, .visibleKeyRangeChanged(lowest: .A1, highest: .G3))
      await store.receive(\.keyboard.scrollTo, .init(midiNoteValue: 33)) {
        $0.keyboard.scrollTo = .init(midiNoteValue: 33)
      }
    }
  }

  @Test
  func reinitializeShowPromptCancel() async throws {
    try await initialized(exhaustivity: .off(showSkippedAssertions: false)) { store in
      await store.send(\.toolBar.delegate, .settingsButtonTapped)
      #expect(store.state.destination != nil)
      await store.send(\.destination.presented.settings.delegate, .reinitialize) {
        $0.destination = .alert(.confirmReinitialize(action: .reinitializeConfirmed))
      }
      await store.send(\.destination.dismiss) {
        $0.destination = nil
      }
      await store.receive(\.appReview.ask)
    }
  }

  @Test
  func reinitializeShowPromptOK() async throws {
    try await initialized(exhaustivity: .off(showSkippedAssertions: false)) { store in
      await store.send(\.toolBar.delegate, .settingsButtonTapped)
      #expect(store.state.destination != nil)
      await store.send(\.destination.presented.settings.delegate, .reinitialize) {
        $0.destination = .alert(.confirmReinitialize(action: .reinitializeConfirmed))
      }
      await store.send(\.destination.presented.alert.reinitializeConfirmed)
    }
  }

  @Test
  func makeWithDependencies() {
    let store = AppRoot.makeWithDependencies()
    #expect(store.state.readyForUse == false)
    @Shared(.isAUv3) var isAUv3
    #expect(isAUv3 == false)
  }

  @Test
  func helpInfoButtonTapped() async throws {
    try await initialized { store in
      await store.send(\.toolBar.helpInfoButtonTapped) {
        $0.toolBar.helpInfoRestoration = .init(effectsPanelVisible: false, tagsListVisible: false, moreButtonsVisible: false)
      }
      await store.receive(\.toolBar.effectsVisibilityButtonTapped)
      await store.receive(\.toolBar.delegate.effectsVisibilityChanged, true)
      await store.receive(\.toolBar.tagsListVisibilityButtonTapped)
      await store.receive(\.toolBar.delegate.tagsListVisibilityChanged, true)
      let visiblePanes = SplitViewVisiblePanes(rawValue: 3)
      await store.receive(\.fontsAndTagsSplit.updatePanesVisibility, visiblePanes) {
        $0.fontsAndTagsSplit.panesVisible = visiblePanes
      }
      await store.receive(\.fontsAndTagsSplit.delegate, .stateChanged(panesVisible: visiblePanes, position: 0.4))
      await store.receive(\.toolBar.delegate.helpInfoButtonTapped) {
        $0.helpInfoSelection = .fontsList
      }
    }
  }

  @Test
  func importFinished() async throws {
    try await initialized { store in
      await store.send(\.toolBar.delegate.importFinished)
      await store.receive(\.tagsList.importFinished)
      await store.receive(\.soundFontsList.importFinished)
      @FetchAll var soundFontInfos: [SoundFontInfo]
      try await $soundFontInfos.load(SoundFontInfo.query(for: Tag.Ubiquitous.all.id))
      #expect(soundFontInfos.count == 1)
      await store.receive(\.soundFontsList.rowsSourceUpdated, soundFontInfos)
    }
  }

  @Test
  func helpInfoSelectionChanged() async throws {
    try await initialized { store in
      // Begin showing help info
      await store.send(\.toolBar.helpInfoButtonTapped) {
        $0.toolBar.helpInfoRestoration = .init(effectsPanelVisible: false, tagsListVisible: false, moreButtonsVisible: false)
      }
      await store.receive(\.toolBar.effectsVisibilityButtonTapped)
      await store.receive(\.toolBar.delegate.effectsVisibilityChanged, true)
      await store.receive(\.toolBar.tagsListVisibilityButtonTapped)
      await store.receive(\.toolBar.delegate.tagsListVisibilityChanged, true)
      var visiblePanes = SplitViewVisiblePanes(rawValue: 3)
      await store.receive(\.fontsAndTagsSplit.updatePanesVisibility, visiblePanes) {
        $0.fontsAndTagsSplit.panesVisible = visiblePanes
      }
      await store.receive(\.fontsAndTagsSplit.delegate, .stateChanged(panesVisible: visiblePanes, position: 0.4))
      await store.receive(\.toolBar.delegate.helpInfoButtonTapped) {
        $0.helpInfoSelection = .fontsList
      }
      // Change help info focus
      await store.send(\.binding.helpInfoSelection.some, .addButton) {
        $0.helpInfoSelection = .addButton
      }
      // Stop showing help info
      await store.send(\.binding.helpInfoSelection.none) {
        $0.helpInfoSelection = nil
      }
      await store.receive(\.toolBar.helpInfoFinished) {
        $0.toolBar.helpInfoRestoration = nil
      }
      await store.receive(\.toolBar.effectsVisibilityButtonTapped)
      await store.receive(\.toolBar.delegate.effectsVisibilityChanged, false)
      await store.receive(\.toolBar.tagsListVisibilityButtonTapped)
      await store.receive(\.toolBar.delegate.tagsListVisibilityChanged, false)
      visiblePanes = SplitViewVisiblePanes(rawValue: 1)
      await store.receive(\.fontsAndTagsSplit.updatePanesVisibility, visiblePanes) {
        $0.fontsAndTagsSplit.panesVisible = visiblePanes
      }
      await store.receive(\.fontsAndTagsSplit.delegate, .stateChanged(panesVisible: visiblePanes, position: 0.4))
    }
  }

  // MARK: - snapshots

  @Test(.snapshots(record: .failed))
  func showNoVolumeToast() async throws {
    withDependencies {
      $0.mainQueue = .immediate
    } operation: {
      let state: AppRoot.State = .init(toastState: .volumeLevelIsZero)
      let store: StoreOf<AppRoot> = .init(initialState: state) { AppRoot() }
      let view: some View = ZStack {
        Color.black
          .ignoresSafeArea(edges: .all)
        AppRootView(store: store)
        // .preferredColorScheme(.dark)
          .environment(\.colorScheme, .dark)
      }

      return TestSupport.assertSnapshot(matching: view)
    }
  }

  @Test(.snapshots(record: .failed))
  func showNoPresetToast() async throws {
    withDependencies {
      $0.mainQueue = .immediate
    } operation: {
      let state: AppRoot.State = .init(toastState: .noActivePreset)
      let store: StoreOf<AppRoot> = .init(initialState: state) { AppRoot() }
      let view: some View = ZStack {
        Color.black
          .ignoresSafeArea(edges: .all)
        AppRootView(store: store)
        // .preferredColorScheme(.dark)
          .environment(\.colorScheme, .dark)
      }
      TestSupport.assertSnapshot(matching: view)
    }
  }

  @Test(.snapshots(record: .failed))
  func appRootViewPreview() async throws {
    withDependencies {
      $0.mainQueue = .immediate
    } operation: {
      TestSupport.assertSnapshot(matching: AppRootView.preview)
    }
  }
}
