// Copyright © 2025 Brad Howes. All rights reserved.

import AVFAudio
import DelayEffect
import DependenciesTestSupport
import FeatureSupport
import Models
import MorkAndMIDI
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
    $0.audioGraph = .liveValue // MockAudioGraph().audioGraph
    $0.audioSession = .liveValue
    $0.avAudioUnitMIDIInstrumentGenerator = await AVAudioUnitMIDIInstrumentGenerator.constant()
    $0.date = .constant(.now)
    $0.defaultDatabase = TestSupport.testDatabase()
    $0.delayDevice = .liveValue
    $0.fileManager = .liveValue
    $0.mainQueue = .immediate
    $0.outputVolume = mockVolume.makeOutputVolume()
    $0.reverbDevice = .liveValue
    $0.continuousClock = ImmediateClock()
  },
  .serialized // due to SF2LibAU creation
)
@MainActor
struct AppRootTests {

  func store(showedTutorial: Bool = true) -> TestStoreOf<AppRoot> {
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

    await store.send(.initialize)
    await store.receive(\.synth.synthAudioUnitCreated) {
      $0.synth.audioSessionActivated = true
      $0.synth.avAudioUnit = avAudioUnit
    }
    await store.receive(\.synth.delegate.audioUnitCreated) {
      $0.keyboard.midiInstrument = $0.synth.avAudioUnit
    }

    await store.withExhaustivity(.off(showSkippedAssertions: false)) {
      await store.receive(\.synth.delegate.running) {
        $0.synth.loadedSoundFontId = 1
        $0.synth.loadedPresetIndex = 0
        $0.toolBar.preset = Preset.with(id: 1)
        $0.toolBar.temporaryStatus = nil
        $0.toastState = nil
        $0.readyForUse = true
        $0.delayEffect.activePresetId = 1
        $0.volumeMonitor.activePresetId = 1
      }
    }

    await store.receive(\.volumeMonitor.delegate.reasonChanged, .noActivePreset) {
      $0.keyboard.muted = true
      $0.toastState = .noActivePreset
    }

    await store.receive(\.soundFontsList.delegate.presetSourceChanged, .active(1))

    await store.receive(\.volumeMonitor.delegate.reasonChanged, .none) {
      $0.keyboard.muted = false
      $0.toastState = .none
    }

    await store.receive(\.presetsList.rowsUpdated, Preset.visible(for: 1), timeout: .seconds(10))

    await store.receive(\.presetsList.showPresetNow, 1, timeout: .seconds(10)) {
      $0.presetsList.scrollToTarget = .preset(1)
    }

    await store.receive(\.synth.lastPresetLoadFinished, timeout: .seconds(10)) {
      $0.synth.firstTimePresetLoaded = false
    }

    try await store.withExhaustivity(exhaustivity) {

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
  func initializeWithMIDI() async throws {
    @Shared(.midi) var midi
    $midi.withLock {
      $0 = MIDI(clientName: "BlahBlah", uniqueId: 123123, midiProto: .v2_0)
    }

    try await initialized { _ in }
  }

  @Test
  func synthStopped() async throws {
    try await initialized { store in
      await store.send(\.synth.delegate.stopped)
    }
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

  @Test(
    .dependencies {
      $0.continuousClock = .immediate
    }
  )
  func processKeyboardAction() async throws {
    try await initialized { store in
      await store.send(\.keyboard.delegate.noteOn, .C4) {
        $0.toolBar.temporaryStatus = .lastPlayedKey("C4")
      }
    }
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
    @Shared(.lastShowedChangesVersion) var lastShowedChangesVersion = ""
    try await initialized(exhaustivity: .off(showSkippedAssertions: false)) { store in
      @Shared(.lastShowedChangesVersion) var lastShowedChangesVersion
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
        $0.synth.firstTimePresetLoaded = false
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
        $0.toastState = .volumeLevelIsZero
        $0.keyboard.muted = true
      }

      await store.send(\.volumeMonitor.delegate.reasonChanged, .noActivePreset)

      await store.send(\.volumeMonitor.delegate.reasonChanged, .none) {
        $0.toastState = nil
        $0.keyboard.muted = false
      }
    }
  }

  @Test
  func showEditPreset() async throws {
    try await initialized { store in
      #expect(store.state.presetsList.sections.isEmpty == false)
      let section = store.state.presetsList.sections.first!
      let preset = section.rows.first!.preset
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
            isActive: true
          )
        )
      }

      await store.send(\.destination.dismiss) {
        $0.destination = nil
      }

      await store.receive(\.presetsList.rowsUpdated, Preset.visible(for: 1))
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
        $0.presetsList.scrollToTarget = .preset(1)
      }
      await store.receive(\.presetsList.rowsUpdated, Preset.visible(for: 1))
    }
  }

  @Test(
    .snapshots(record: .failed)
  )
  func showNoVolumeToast() async throws {
    let state: AppRoot.State = .init(toastState: .volumeLevelIsZero)
    let store: StoreOf<AppRoot> = .init(initialState: state) { AppRoot() }

    var view: some View {
      return ZStack {
        Color.black
          .ignoresSafeArea(edges: .all)
        AppRootView(store: store)
        // .preferredColorScheme(.dark)
          .environment(\.colorScheme, .dark)
      }
    }

    TestSupport.assertSnapshot(matching: view)
  }

  @Test(
    .snapshots(record: .failed)
  )
  func showNoPresetToast() async throws {
    let state: AppRoot.State = .init(toastState: .noActivePreset)
    let store: StoreOf<AppRoot> = .init(initialState: state) { AppRoot() }

    var view: some View {
      return ZStack {
        Color.black
          .ignoresSafeArea(edges: .all)
        AppRootView(store: store)
        // .preferredColorScheme(.dark)
          .environment(\.colorScheme, .dark)
      }
    }

    TestSupport.assertSnapshot(matching: view)
  }

  @Test
  func editingPresetVisibilityChanged() async throws {
    try await initialized { store in

      await store.send(\.toolBar.delegate.editingPresetVisibilityChanged, true) {
        $0.presetsList.editingVisibility = true
      }

      await store.receive(\.presetsList.rowsUpdated) {
        $0.presetsList.presets = Preset.all(for: 1)
        $0.presetsList.sections = group(Preset.all(for: 1), presetSource: .active(1), activePresetId: 1, searching: false)
      }

      await store.send(\.toolBar.delegate.editingPresetVisibilityChanged, false) {
        $0.presetsList.editingVisibility = false
      }

      await store.receive(\.presetsList.rowsUpdated) {
        $0.presetsList.presets = Preset.visible(for: 1)
        $0.presetsList.sections = group(Preset.visible(for: 1), presetSource: .active(1), activePresetId: 1, searching: false)
      }
    }
  }

  @Test
  func effectsVisibilityChanged() async throws {
    @Shared(.effectsPanelVisible) var effectsPanelVisible
    try await initialized { store in
      await store.send(\.toolBar.delegate.effectsVisibilityChanged, true)
      #expect(effectsPanelVisible == true)
      await store.send(\.toolBar.delegate.effectsVisibilityChanged, false)
      #expect(effectsPanelVisible == false)
    }
  }

  @Test(
    .dependencies {
      $0.continuousClock = .immediate
    }
  )
  func presetNameTapped() async throws {
    try await initialized { store in
      await store.send(\.toolBar.delegate.presetNameTapped)
      await store.receive(\.soundFontsList.delegate.presetSourceChanged, .active(1), timeout: .seconds(30))
      await store.receive(\.presetsList.rowsUpdated, Preset.visible(for: 1))
      await store.receive(\.presetsList.showPresetNow, 1)
    }
  }

  @Test
  func panic() async throws {
    try await initialized { store in
      await store.send(\.keyboard.visualizeMIDINote, .on(.C4)) {
        $0.keyboard.noteCounters[60] = 1
      }
      await store.send(\.toolBar.delegate.panic) {
        $0.keyboard.noteCounters[60] = 0
      }
    }
  }

  @Test
  func tagsListVisibilityChanged() async throws {
    try await initialized { store in
      await store.send(\.toolBar.delegate.tagsListVisibilityChanged, true) {
        $0.fontsAndTagsSplit.panesVisible = .init(rawValue: 3)
      }
      await store.receive(\.fontsAndTagsSplit.delegate, .stateChanged(panesVisible: .init(rawValue: 3), position: 0.4))
      await store.send(\.toolBar.delegate.tagsListVisibilityChanged, false) {
        $0.fontsAndTagsSplit.panesVisible = .init(rawValue: 1)
      }
      await store.receive(\.fontsAndTagsSplit.delegate, .stateChanged(panesVisible: .init(rawValue: 1), position: 0.4))
    }
  }

  @Test
  func visibleKeyRangeChanged() async throws {
    try await initialized { store in
      await store.send(\.toolBar.delegate, .visibleKeyRangeChanged(lowest: .A1, highest: .G3)) {
        $0.keyboard.scrollTo = .init(midiNoteValue: 33)
      }
    }
  }

  @Test(
    .snapshots(record: .failed)
  )
  func appRootViewPreview() async throws {
    TestSupport.assertSnapshot(matching: AppRootView.preview)
  }
}
